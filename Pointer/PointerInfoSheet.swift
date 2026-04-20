import CoreLocation
import SwiftUI

/// Device GPS, selected target geography, and great-circle hint versus the catalog point.
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
            "Distance and initial bearing use a spherical-Earth great circle. The arrow aims along the straight chord in WGS84 (ellipsoid surface points → ECEF → local east/north/up), so distant targets pick up a slight tilt below the astronomical horizon — not a flat-map bearing only."
          )
          .font(.caption)
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

  private var targetSection: some View {
    let t = aimSession.selectedGroundTarget
    return VStack(alignment: .leading, spacing: 8) {
      Text(t.displayName)
        .font(.headline)
      Text(formatLatLon(latitude: t.latitude, longitude: t.longitude))
        .font(.body.monospacedDigit())
      Text(t.notes)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var relativeSection: some View {
    let t = aimSession.selectedGroundTarget
    if location.isAuthorized, let fix = location.lastLocation {
      let from = fix.coordinate
      let to = CLLocationCoordinate2D(latitude: t.latitude, longitude: t.longitude)
      let origin = CLLocation(latitude: from.latitude, longitude: from.longitude)
      let dest = CLLocation(latitude: to.latitude, longitude: to.longitude)
      let meters = origin.distance(from: dest)
      let bearing = Geodesy.initialBearingDegrees(from: from, to: to)

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
