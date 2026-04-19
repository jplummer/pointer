import SwiftUI
import SceneKit
import CoreMotion
import simd

struct ArrowSceneView: UIViewRepresentable {
  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeUIView(context: Context) -> SCNView {
    let view = SCNView()
    view.backgroundColor = .black
    view.antialiasingMode = .multisampling4X
    view.allowsCameraControl = false

    let scene = SCNScene()
    view.scene = scene
    view.autoenablesDefaultLighting = true

    let cameraNode = SCNNode()
    cameraNode.camera = SCNCamera()
    cameraNode.position = SCNVector3(0, 0, 6)
    scene.rootNode.addChildNode(cameraNode)

    let arrow = Coordinator.buildArrowNode()
    scene.rootNode.addChildNode(arrow)

    context.coordinator.cameraNode = cameraNode
    context.coordinator.motionManager.startUpdates { attitude in
      let q = attitude.quaternion
      let device = simd_quaternion(Float(q.x), Float(q.y), Float(q.z), Float(q.w))
      // Camera matches device orientation so the scene feels stable while you move the phone.
      cameraNode.simdOrientation = device
    }

    return view
  }

  func updateUIView(_ uiView: SCNView, context: Context) {}

  final class Coordinator {
    fileprivate let motionManager = MotionController()
    var cameraNode: SCNNode?

    deinit {
      motionManager.stopUpdates()
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
