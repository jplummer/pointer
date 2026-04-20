import CoreLocation
import CoreMotion
import SceneKit
import SwiftUI
import simd

/// Core Motion + SceneKit: a **stabilized** group counter-rotates with device attitude so content stays aligned
/// with the motion reference frame. The arrow twists local **+Y** (shaft) toward the **WGS84 ECEF chord** to the catalog point
/// in local east/north/up (`.xTrueNorthZVertical`), including dip for distant targets. Without a usable GPS fix or when the aim
/// vector degenerates, falls back to an arbitrary horizontal reference (`.xArbitraryZVertical`) until a fix returns.
struct ArrowSceneView: UIViewRepresentable {
  var aimMode: AimSession.AimMode
  var userCoordinate: CLLocationCoordinate2D?
  @Binding var isSceneReady: Bool

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeUIView(context: Context) -> SCNView {
    let view = SCNView()
    view.isOpaque = false
    view.backgroundColor = .clear
    view.antialiasingMode = .multisampling4X
    view.allowsCameraControl = false

    let scene = SCNScene()
    scene.background.contents = UIColor.clear
    view.scene = scene
    view.autoenablesDefaultLighting = true

    let cameraNode = SCNNode()
    cameraNode.camera = SCNCamera()
    cameraNode.position = SCNVector3(0, 0, 6)
    cameraNode.simdOrientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    scene.rootNode.addChildNode(cameraNode)

    let stabilized = SCNNode()
    scene.rootNode.addChildNode(stabilized)

    let arrow = Coordinator.buildArrowNode()
    stabilized.addChildNode(arrow)

    let coordinator = context.coordinator
    coordinator.arrowNode = arrow
    coordinator.stabilizedNode = stabilized
    coordinator.readyBinding = $isSceneReady
    coordinator.sync(aimMode: aimMode, userCoordinate: userCoordinate)
    view.delegate = coordinator
    return view
  }

  func updateUIView(_ uiView: SCNView, context: Context) {
    context.coordinator.readyBinding = $isSceneReady
    context.coordinator.sync(aimMode: aimMode, userCoordinate: userCoordinate)
  }

  final class Coordinator: NSObject, SCNSceneRendererDelegate {
    fileprivate let motionManager = MotionController()
    weak var arrowNode: SCNNode?
    weak var stabilizedNode: SCNNode?
    var readyBinding: Binding<Bool>?
    private var postedFirstFrame = false
    private var lastMotionFrame: CMAttitudeReferenceFrame?

    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
      guard !postedFirstFrame else { return }
      postedFirstFrame = true
      DispatchQueue.main.async { [weak self] in
        self?.readyBinding?.wrappedValue = true
      }
    }

    deinit {
      motionManager.stopUpdates()
    }

    func sync(aimMode: AimSession.AimMode, userCoordinate: CLLocationCoordinate2D?) {
      guard let arrow = arrowNode, let stabilized = stabilizedNode else { return }
      let (twist, frame) = Self.twistAndFrame(aimMode: aimMode, userCoordinate: userCoordinate)
      arrow.simdOrientation = twist

      let frameChanged = lastMotionFrame != frame
      if frameChanged {
        lastMotionFrame = frame
        motionManager.restart(referenceFrame: frame) { attitude in
          let q = attitude.quaternion
          let device = simd_quaternion(Float(q.x), Float(q.y), Float(q.z), Float(q.w))
          stabilized.simdOrientation = simd_inverse(device)
        }
      }
    }

    /// Rotation taking unit vector `from` onto unit vector `to`.
    static func quaternionAligning(from: simd_float3, to: simd_float3) -> simd_quatf {
      let a = simd_normalize(from)
      let b = simd_normalize(to)
      let c = simd_cross(a, b)
      let d = simd_dot(a, b)
      let epsilon: Float = 1e-6
      if simd_length(c) < epsilon {
        if d > 0 {
          return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        }
        let ortho =
          abs(a.x) < 0.9 ? simd_normalize(simd_cross(a, simd_float3(1, 0, 0))) : simd_normalize(simd_cross(a, simd_float3(0, 1, 0)))
        return simd_quaternion(Float.pi, ortho)
      }
      let axis = simd_normalize(c)
      let angle = acos(max(-1, min(1, d)))
      return simd_quaternion(angle, axis)
    }

    /// True-north ENU chord vs temporary arbitrary-horizontal aim when geographic direction is unavailable.
    private static func twistAndFrame(
      aimMode: AimSession.AimMode,
      userCoordinate: CLLocationCoordinate2D?
    ) -> (simd_quatf, CMAttitudeReferenceFrame) {
      switch aimMode {
      case .ground(let target):
        guard let userCoordinate else {
          return fallbackArbitraryHorizontalAim()
        }
        let destCoord = CLLocationCoordinate2D(latitude: target.latitude, longitude: target.longitude)
        let origin = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
        let dest = CLLocation(latitude: destCoord.latitude, longitude: destCoord.longitude)
        if origin.distance(from: dest) < 3 {
          return fallbackArbitraryHorizontalAim()
        }
        guard let dir = Geodesy.trueNorthENUChordUnit(from: userCoordinate, to: destCoord) else {
          return fallbackArbitraryHorizontalAim()
        }
        let twist = quaternionAligning(from: simd_normalize(simd_float3(0, 1, 0)), to: dir)
        return (twist, .xTrueNorthZVertical)
      }
    }

    /// +X in `.xArbitraryZVertical` — used only when there is no valid user→target chord (no fix, coincident, degenerate).
    private static func fallbackArbitraryHorizontalAim() -> (simd_quatf, CMAttitudeReferenceFrame) {
      let ref = simd_normalize(simd_float3(1, 0, 0))
      let twist = quaternionAligning(from: simd_normalize(simd_float3(0, 1, 0)), to: ref)
      return (twist, .xArbitraryZVertical)
    }

    static func buildArrowNode() -> SCNNode {
      let shaft = SCNCylinder(radius: 0.08, height: 2.2)
      shaft.firstMaterial?.diffuse.contents = UIColor.systemOrange

      let cone = SCNCone(topRadius: 0, bottomRadius: 0.28, height: 0.65)
      cone.firstMaterial?.diffuse.contents = UIColor.systemYellow

      let shaftNode = SCNNode(geometry: shaft)
      let coneNode = SCNNode(geometry: cone)
      coneNode.position = SCNVector3(0, 1.35, 0)

      let root = SCNNode()
      root.addChildNode(shaftNode)
      root.addChildNode(coneNode)
      return root
    }
  }

  final class MotionController {
    private let motion = CMMotionManager()

    func restart(referenceFrame: CMAttitudeReferenceFrame, handler: @escaping (CMAttitude) -> Void) {
      motion.stopDeviceMotionUpdates()
      guard motion.isDeviceMotionAvailable else { return }
      motion.deviceMotionUpdateInterval = 1.0 / 60.0
      motion.startDeviceMotionUpdates(using: referenceFrame, to: .main) { data, _ in
        guard let attitude = data?.attitude else { return }
        handler(attitude)
      }
    }

    func stopUpdates() {
      motion.stopDeviceMotionUpdates()
    }
  }
}
