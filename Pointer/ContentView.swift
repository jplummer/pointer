import CoreLocation
import SwiftUI
import UIKit

struct ContentView: View {
  @StateObject private var aimSession = AimSession()
  @StateObject private var location = LocationService()
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

        locationStrip

        footerBar
      }
    }
    .onAppear {
      location.begin()
    }
  }

  private var locationStrip: some View {
    Group {
      switch location.authorizationStatus {
      case .notDetermined:
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "location.circle")
            .foregroundStyle(Color.white.opacity(0.95))
          Text("Tap Allow when iOS asks — Pointer needs your position on Earth for bearings.")
            .foregroundStyle(Color.white.opacity(0.92))
            .fixedSize(horizontal: false, vertical: true)
        }
      case .restricted:
        restrictedOrDeniedCopy(isRestricted: true)
      case .denied:
        restrictedOrDeniedCopy(isRestricted: false)
      case .authorizedAlways, .authorizedWhenInUse:
        authorizedReadout
      @unknown default:
        Text("Unknown authorization state.")
          .foregroundStyle(Color.white)
      }
    }
    .font(.caption.monospacedDigit())
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 14)
    .padding(.vertical, 11)
    .background(Color.black.opacity(0.74))
    .overlay(alignment: .top) {
      Divider().overlay(Color.white.opacity(0.14))
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilitySummary)
  }

  private var accessibilitySummary: String {
    switch location.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      guard let fix = location.lastLocation else {
        return "Location authorized; waiting for fix."
      }
      return "Location \(formatCoordinateSummary(fix))"
    case .denied:
      return "Location denied; open Settings to enable."
    default:
      return "Location status \(String(describing: location.authorizationStatus))"
    }
  }

  private var authorizedReadout: some View {
    Group {
      if let fix = location.lastLocation {
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Image(systemName: "location.fill")
              .foregroundStyle(Color.green.opacity(0.95))
            Text("Location")
              .font(.caption.weight(.semibold))
              .foregroundStyle(Color.white.opacity(0.88))
              .textCase(.uppercase)
              .tracking(0.4)
          }
          Text(formatCoordinateLine(fix))
            .foregroundStyle(Color.white)
          if let err = location.lastError {
            Text(err.localizedDescription)
              .font(.caption2)
              .foregroundStyle(Color.orange.opacity(0.95))
          }
        }
      } else {
        HStack(spacing: 8) {
          ProgressView()
            .tint(.white)
          Text("Waiting for first GPS fix…")
            .foregroundStyle(Color.white.opacity(0.92))
        }
      }
    }
  }

  private func restrictedOrDeniedCopy(isRestricted: Bool) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(isRestricted ? "Location restricted on this device." : "Location access denied.")
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.white)
      Text("Enable Location Services for Pointer in Settings (Privacy & Security → Location Services).")
        .foregroundStyle(Color.white.opacity(0.88))
        .fixedSize(horizontal: false, vertical: true)
      Button {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          openURL(url)
        }
      } label: {
        Text("Open Settings")
          .font(.caption.weight(.semibold))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background(Color.white.opacity(0.16))
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      }
      .buttonStyle(.plain)
      .foregroundStyle(Color.white)
    }
  }

  private func formatCoordinateLine(_ fix: CLLocation) -> String {
    let lat = fix.coordinate.latitude
    let lon = fix.coordinate.longitude
    let h = fix.horizontalAccuracy
    let latH = lat >= 0 ? "N" : "S"
    let lonH = lon >= 0 ? "E" : "W"
    return String(
      format: "%.5f° %@ · %.5f° %@ · ±%.0f m",
      abs(lat), latH, abs(lon), lonH, h
    )
  }

  private func formatCoordinateSummary(_ fix: CLLocation) -> String {
    formatCoordinateLine(fix)
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
      return "Allow location so Pointer can aim toward places on Earth."
    }
    if location.lastLocation == nil {
      return "Stand by for a GPS fix; then we wire bearing math to the arrow."
    }
    switch aimSession.aimMode {
    case .stubMotionReference:
      return "Location ready. Next: bearing math — arrow follows the stub axis, then catalog picks."
    case .ground:
      return "Location ready. Next: bearing math toward the selected place."
    }
  }
}
