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

        HStack(alignment: .bottom) {
          infoButton
            .padding(.leading, 12)
            .padding(.bottom, 4)
          Spacer(minLength: 0)
        }

        footerBar
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
    .accessibilityLabel("Location, target, and build details")
  }

  private var footerBar: some View {
    Text(footerCopy)
      .font(.footnote.weight(.medium))
      .foregroundStyle(Color.white)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 18)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity)
      .background {
        Rectangle()
          .fill(Color.black.opacity(0.78))
          .ignoresSafeArea(edges: .bottom)
      }
      .overlay(alignment: .top) {
        Divider()
          .overlay(Color.white.opacity(0.18))
      }
  }

  private var footerCopy: String {
    guard location.isAuthorized else {
      return "Open the info panel (bottom left) for location status, or allow access in Settings."
    }
    if location.lastLocation == nil {
      return "Waiting for a GPS fix. Use the info panel to see details."
    }
    switch aimSession.aimMode {
    case .stubMotionReference:
      return "Location ready. Next: bearing math — arrow follows the stub, then catalog places."
    case .ground:
      return "Location ready. Next: bearing math toward the selected place."
    }
  }
}
