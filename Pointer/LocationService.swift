import CoreLocation
import Foundation

/// When-in-use location for bearing math (Step 4). Starts updates after authorization.
final class LocationService: NSObject, ObservableObject {
  @Published private(set) var authorizationStatus: CLAuthorizationStatus
  @Published private(set) var lastLocation: CLLocation?
  @Published private(set) var lastError: Error?

  private let manager = CLLocationManager()

  override init() {
    let probe = CLLocationManager()
    authorizationStatus = probe.authorizationStatus
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = 5
  }

  /// Request authorization if needed, then start continuous updates when allowed.
  func begin() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.authorizationStatus = self.manager.authorizationStatus
      switch self.authorizationStatus {
      case .notDetermined:
        self.manager.requestWhenInUseAuthorization()
      case .authorizedAlways, .authorizedWhenInUse:
        self.manager.startUpdatingLocation()
      default:
        break
      }
    }
  }

  func stop() {
    DispatchQueue.main.async { [weak self] in
      self?.manager.stopUpdatingLocation()
    }
  }

  var isAuthorized: Bool {
    authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
  }
}

extension LocationService: CLLocationManagerDelegate {
  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let status = manager.authorizationStatus
      self.authorizationStatus = status
      switch status {
      case .authorizedAlways, .authorizedWhenInUse:
        manager.startUpdatingLocation()
      default:
        break
      }
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      guard let fix = locations.last else { return }
      self.lastLocation = fix
      self.lastError = nil
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    DispatchQueue.main.async { [weak self] in
      self?.lastError = error
    }
  }
}
