import CoreLocation
import SwiftUI
import UIKit

/// Device GPS, selected target geography, great-circle hint, and build metadata.
struct PointerInfoSheet: View {
  @ObservedObject var location: LocationService
  @ObservedObject var aimSession: AimSession
  var openSettings: () -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section {
          deviceLocationSection
        } header: {
          Text("This device")
        }

        Section {
          targetSection
        } header: {
          Text("Selected target")
        }

        Section {
          relativeSection
        } header: {
          Text("Relative to you")
        } footer: {
          Text(
            "Distance and bearing use a spherical-Earth model (WGS84-like great circle). They do not yet drive the on-screen arrow."
          )
          .font(.caption)
        }

        Section {
          nextStepsSection
        } header: {
          Text("Next steps")
        } footer: {
          Text("Implementation roadmap — the camera view stays minimal until bearing drives the arrow.")
            .font(.caption)
        }

        Section {
          developmentSection
        } header: {
          Text("Development")
        }
      }
      .navigationTitle("Details")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }

  @ViewBuilder
  private var deviceLocationSection: some View {
    switch location.authorizationStatus {
    case .notDetermined:
      Label("Waiting for permission — respond to the system location prompt.", systemImage: "location.circle")
    case .restricted:
      restrictedLabel(isRestricted: true)
    case .denied:
      restrictedLabel(isRestricted: false)
    case .authorizedAlways, .authorizedWhenInUse:
      if let fix = location.lastLocation {
        VStack(alignment: .leading, spacing: 8) {
          Text(formatCoordinateLine(fix))
            .font(.body.monospacedDigit())
          Text("Horizontal accuracy ±\(Int(fix.horizontalAccuracy)) m")
            .font(.caption)
            .foregroundStyle(.secondary)
          if let err = location.lastError {
            Text(err.localizedDescription)
              .font(.caption)
              .foregroundStyle(.orange)
          }
        }
      } else {
        Label("Authorized — waiting for first GPS fix.", systemImage: "antenna.radiowaves.left.and.right")
      }
    @unknown default:
      Text("Unknown authorization state.")
    }
  }

  private func restrictedLabel(isRestricted: Bool) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(isRestricted ? "Location is restricted on this device." : "Location access was denied for Pointer.")
      Button("Open Settings", action: openSettings)
        .buttonStyle(.borderedProminent)
    }
  }

  @ViewBuilder
  private var targetSection: some View {
    switch aimSession.aimMode {
    case .stubMotionReference:
      VStack(alignment: .leading, spacing: 8) {
        Text(AimSession.AimMode.stubMotionReference.title)
          .font(.headline)
        Text(AimSession.AimMode.stubMotionReference.caption)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Text("No latitude/longitude — this mode uses Core Motion’s reference axes only.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    case .ground(let t):
      VStack(alignment: .leading, spacing: 8) {
        Text(t.displayName)
          .font(.headline)
        Text(formatLatLon(latitude: t.latitude, longitude: t.longitude))
          .font(.body.monospacedDigit())
        Text(t.notes)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private var relativeSection: some View {
    switch aimSession.aimMode {
    case .stubMotionReference:
      Text("Choose a place from the catalog to see distance and bearing from your position.")
        .foregroundStyle(.secondary)
    case .ground(let t):
      if location.isAuthorized, let fix = location.lastLocation {
        let from = fix.coordinate
        let to = CLLocationCoordinate2D(latitude: t.latitude, longitude: t.longitude)
        let origin = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let dest = CLLocation(latitude: to.latitude, longitude: to.longitude)
        let meters = origin.distance(from: dest)
        let bearing = GeoMath.initialBearingDegrees(from: from, to: to)

        VStack(alignment: .leading, spacing: 8) {
          if meters >= 1000 {
            Text("\(String(format: "%.2f", meters / 1000)) km apart (great-circle)")
          } else {
            Text("\(Int(round(meters))) m apart (great-circle)")
          }
          Text("Initial bearing \(bearingFormatted(bearing)) (clockwise from north)")
            .font(.body.monospacedDigit())
        }
      } else if !location.isAuthorized {
        Text("Allow location to compute distance and bearing toward this place.")
          .foregroundStyle(.secondary)
      } else {
        Text("Waiting for a GPS fix to compute distance and bearing.")
          .foregroundStyle(.secondary)
      }
    }
  }

  private var nextStepsSection: some View {
    Text(nextStepsCopy)
      .font(.subheadline)
      .fixedSize(horizontal: false, vertical: true)
  }

  private var nextStepsCopy: String {
    guard location.isAuthorized else {
      return "Allow location when iOS asks, or enable Pointer under Settings → Privacy & Security → Location Services. Without it, directions on Earth stay unavailable."
    }
    if location.lastLocation == nil {
      return "Waiting for a GPS fix. Try a clearer view of the sky or step outdoors if this lingers."
    }
    switch aimSession.aimMode {
    case .stubMotionReference:
      return "Location ready. Next: bearing math — align the SceneKit arrow with the motion stub, then aim at catalog coordinates using your position."
    case .ground:
      return "Location ready. Next: bearing math — rotate the arrow so it points toward this target on the real horizon."
    }
  }

  private var developmentSection: some View {
    let bundle = Bundle.main
    let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    let bid = bundle.bundleIdentifier ?? "—"

    return VStack(alignment: .leading, spacing: 6) {
      LabeledContent("Version", value: version)
      LabeledContent("Build", value: build)
      LabeledContent("Bundle ID", value: bid)
    }
    .font(.subheadline.monospacedDigit())
  }

  private func formatCoordinateLine(_ fix: CLLocation) -> String {
    formatLatLon(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude)
  }

  private func formatLatLon(latitude: Double, longitude: Double) -> String {
    let latH = latitude >= 0 ? "N" : "S"
    let lonH = longitude >= 0 ? "E" : "W"
    return String(
      format: "%.6f° %@ · %.6f° %@",
      abs(latitude), latH, abs(longitude), lonH
    )
  }

  private func bearingFormatted(_ degrees: Double) -> String {
    String(format: "%.1f°", degrees)
  }
}

// MARK: - Great-circle initial bearing (spherical Earth)

private enum GeoMath {
  /// Clockwise from true north, 0…360°.
  static func initialBearingDegrees(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    let φ1 = from.latitude * .pi / 180
    let φ2 = to.latitude * .pi / 180
    let Δλ = (to.longitude - from.longitude) * .pi / 180
    let y = sin(Δλ) * cos(φ2)
    let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
    let θ = atan2(y, x)
    let deg = θ * 180 / .pi
    return (deg + 360).truncatingRemainder(dividingBy: 360)
  }
}
