import CoreLocation
import SwiftUI
import UIKit

struct ContentView: View {
  @StateObject private var aimSession = AimSession()
  @StateObject private var location = LocationService()
  @State private var isInfoPresented = false
  @State private var arrowSceneReady = false
  @Environment(\.openURL) private var openURL

  var body: some View {
    ZStack {
      CameraPreviewView()
        .ignoresSafeArea()

      ArrowSceneView(
        aimMode: aimSession.aimMode,
        userCoordinate: location.lastLocation?.coordinate,
        isSceneReady: $arrowSceneReady
      )
      .ignoresSafeArea()

      if !arrowSceneReady {
        loadingOverCamera
      }

      VStack(spacing: 0) {
        TargetPickerExpando(session: aimSession)
          .padding(.horizontal, 16)
          .padding(.top, 12)

        Spacer(minLength: 0)

        HStack {
          infoButton
          Spacer(minLength: 0)
        }
        .padding(.leading, 12)
        .padding(.bottom, 16)
      }
    }
    .onAppear {
      location.begin()
    }
    .task {
      // If SceneKit never fires the first render callback (unexpected), avoid an endless spinner.
      try? await Task.sleep(for: .seconds(6))
      if !arrowSceneReady {
        arrowSceneReady = true
      }
    }
    .sheet(isPresented: $isInfoPresented) {
      PointerInfoSheet(
        location: location,
        aimSession: aimSession,
        openSettings: {
          if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
          }
        }
      )
    }
  }

  /// Spinner until SceneKit’s first draw. Full-screen dim removed so the **camera preview stays visible**; only this card sits on top.
  private var loadingOverCamera: some View {
    VStack {
      Spacer()
      VStack(spacing: 14) {
        ProgressView()
          .progressViewStyle(.circular)
          .tint(.white)
          .scaleEffect(1.35)
        Text("Preparing the on-screen arrow")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.white)
          .multilineTextAlignment(.center)
      }
      .padding(.horizontal, 28)
      .padding(.vertical, 24)
      .background {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(.ultraThinMaterial)
          .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 10)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Preparing the on-screen arrow, please wait")
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .allowsHitTesting(false)
  }

  private var infoButton: some View {
    Button {
      isInfoPresented = true
    } label: {
      Image(systemName: "info.circle.fill")
        .font(.title2)
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.white)
        .padding(10)
        .background {
          Circle()
            .fill(Color.black.opacity(0.55))
            .overlay {
              Circle()
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            }
        }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Details: location, target, and distance")
  }
}
