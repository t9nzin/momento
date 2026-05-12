import Foundation
import CoreLocation

/// Thin CLLocationManager wrapper. Started when the user is about to capture a
/// stamp so a fresh GPS fix is available the moment they punch. Failures are
/// non-fatal — the stamp simply saves without a coordinate.
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared = LocationProvider()

    private let manager = CLLocationManager()
    private(set) var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func start() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    /// Returns the latest coordinate if it's fresher than `maxAge` seconds.
    func currentCoordinate(maxAge: TimeInterval = 120) -> CLLocationCoordinate2D? {
        guard let loc = lastLocation else { return nil }
        if Date().timeIntervalSince(loc.timestamp) > maxAge { return nil }
        return loc.coordinate
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let last = locations.last {
            lastLocation = last
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Non-fatal — stamp just won't get a coordinate.
    }
}
