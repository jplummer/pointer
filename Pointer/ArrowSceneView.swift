import SwiftUI
import SceneKit
import CoreMotion
import simd

/// Step 3 (PLAN): fixed camera; a **stabilized** group counter-rotates with device attitude so content can
/// stay aligned with the reference frame. The arrow applies a constant twist so its tip (+Y) aims along a
/// stub “target” axis (+X in the reference frame)—not geographic north; that comes after Core Location.
struct ArrowSceneView: UIViewRepresentable {
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

    // Counter-rotates with device so children can represent directions in the motion reference frame.
    let stabilized = SCNNode()
    scene.rootNode.addChildNode(stabilized)
    context.coordinator.stabilizedNode = stabilized

    let arrow = Coordinator.buildArrowNode()
    // Local +Y (shaft) should align with parent +X — stub “target” direction in the reference frame.
    let stub = simd_normalize(simd_float3(1, 0, 0))
    let twist = Coordinator.quaternionAligning(
      from: simd_normalize(simd_float3(0, 1, 0)),
      to: stub
    )
    arrow.simdOrientation = twist
    stabilized.addChildNode(arrow)

    let coordinator = context.coordinator
    coordinator.motionManager.startUpdates { [weak coordinator] attitude in
      guard let coordinator else { return }
      let q = attitude.quaternion
      let device = simd_quaternion(Float(q.x), Float(q.y), Float(q.z), Float(q.w))
      coordinator.stabilizedNode?.simdOrientation = simd_inverse(device)
    }

    return view
  }

  func updateUIView(_ uiView: SCNView, context: Context) {}

  final class Coordinator {
    fileprivate let motionManager = MotionController()
    var stabilizedNode: SCNNode?

    deinit {
      motionManager.stopUpdates()
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
        // 180° — pick any orthogonal axis.
        let ortho = abs(a.x) < 0.9 ? simd_normalize(simd_cross(a, simd_float3(1, 0, 0))) : simd_normalize(simd_cross(a, simd_float3(0, 1, 0)))
        return simd_quaternion(Float.pi, ortho)
      }
      let axis = simd_normalize(c)
      let angle = acos(max(-1, min(1, d)))
      return simd_quaternion(angle, axis)
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

    func startUpdates(handler: @escaping (CMAttitude) -> Void) {
      guard motion.isDeviceMotionAvailable else { return }
      motion.deviceMotionUpdateInterval = 1.0 / 60.0
      motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { data, _ in
        guard let attitude = data?.attitude else { return }
        handler(attitude)
      }
    }

    func stopUpdates() {
      motion.stopDeviceMotionUpdates()
    }
  }
}
