import CoreLocation
import SwiftUI
import UIKit

struct ContentView: View {
  @StateObject private var aimSession = AimSession()
  @StateObject private var location = LocationService()
  @State private var isInfoPresented = false
  @Environment(\.openURL) private var openURL

  var body: some View {
    ZStack {
      CameraPreviewView()
        .ignoresSafeArea()

      ArrowSceneView()
        .ignoresSafeArea()

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
    .accessibilityLabel("Details: location, target, next steps, and build info")
  }
}
