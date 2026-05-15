import CoreLocation
import Foundation

@MainActor
final class DeviceLocationProvider: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func currentCoordinate() async throws -> CLLocationCoordinate2D {
        if manager.authorizationStatus == .notDetermined {
            try await requestAuthorization()
        }

        guard isAuthorized else {
            throw WeatherError.locationUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    private func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { continuation in
            authorizationContinuation = continuation
#if os(macOS)
            manager.requestAlwaysAuthorization()
#else
            manager.requestWhenInUseAuthorization()
#endif
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
#if os(macOS)
        switch manager.authorizationStatus {
        case .authorized:
            authorizationContinuation?.resume()
            authorizationContinuation = nil
        case .denied, .restricted:
            authorizationContinuation?.resume(throwing: WeatherError.locationUnavailable)
            authorizationContinuation = nil
        case .notDetermined:
            break
        case .authorizedAlways, .authorizedWhenInUse:
            authorizationContinuation?.resume()
            authorizationContinuation = nil
        @unknown default:
            authorizationContinuation?.resume(throwing: WeatherError.locationUnavailable)
            authorizationContinuation = nil
        }
#else
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            authorizationContinuation?.resume()
            authorizationContinuation = nil
        case .denied, .restricted:
            authorizationContinuation?.resume(throwing: WeatherError.locationUnavailable)
            authorizationContinuation = nil
        case .notDetermined:
            break
        @unknown default:
            authorizationContinuation?.resume(throwing: WeatherError.locationUnavailable)
            authorizationContinuation = nil
        }
#endif
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            continuation?.resume(throwing: WeatherError.locationUnavailable)
            continuation = nil
            return
        }

        continuation?.resume(returning: coordinate)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    private var isAuthorized: Bool {
#if os(macOS)
        manager.authorizationStatus == .authorized
#else
        manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
#endif
    }
}
