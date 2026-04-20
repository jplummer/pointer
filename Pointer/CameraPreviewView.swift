import AVFoundation
import SwiftUI

/// Live camera backdrop (rear wide). Session starts after video authorization.
struct CameraPreviewView: UIViewRepresentable {
  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeUIView(context: Context) -> PreviewHost {
    let host = PreviewHost()
    context.coordinator.previewLayer = host.previewLayer
    context.coordinator.configureIfAuthorized()
    return host
  }

  func updateUIView(_ uiView: PreviewHost, context: Context) {}

  static func dismantleUIView(_ uiView: PreviewHost, coordinator: Coordinator) {
    coordinator.shutdown()
  }

  final class Coordinator {
    let session = AVCaptureSession()
    weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var configured = false

    func configureIfAuthorized() {
      switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .authorized:
        configureSessionAndRun()
      case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { granted in
          DispatchQueue.main.async {
            guard granted else { return }
            self.configureSessionAndRun()
          }
        }
      default:
        break
      }
    }

    func configureSessionAndRun() {
      guard !configured else {
        DispatchQueue.global(qos: .userInitiated).async { [session] in
          if !session.isRunning {
            session.startRunning()
          }
        }
        return
      }

      session.beginConfiguration()
      session.sessionPreset = .high

      guard
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
        let input = try? AVCaptureDeviceInput(device: device),
        session.canAddInput(input)
      else {
        session.commitConfiguration()
        return
      }
      session.addInput(input)
      session.commitConfiguration()
      configured = true

      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.previewLayer?.session = self.session
      }

      DispatchQueue.global(qos: .userInitiated).async { [session] in
        if !session.isRunning {
          session.startRunning()
        }
      }
    }

    func shutdown() {
      DispatchQueue.global(qos: .userInitiated).async { [session] in
        if session.isRunning {
          session.stopRunning()
        }
      }
    }

    deinit {
      shutdown()
    }
  }

  final class PreviewHost: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: CGRect) {
      super.init(frame: frame)
      isOpaque = false
      backgroundColor = .black
      previewLayer.videoGravity = .resizeAspectFill
      layer.insertSublayer(previewLayer, at: 0)
    }

    required init?(coder: NSCoder) {
      nil
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      previewLayer.frame = bounds
    }
  }
}
