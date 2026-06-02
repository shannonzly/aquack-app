//
//  LocationManager.swift
//  Aquack
//

import CoreLocation
import OSLog

enum LocationError: Error {
    case timeout
    case notAuthorized
}

@MainActor
final class LocationManager: NSObject, CLLocationManagerDelegate {

    static let shared = LocationManager()

    private let manager = CLLocationManager()
    private static let log = Logger(subsystem: "com.xiaomingli.aquack", category: "Location")

    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authorizationContinuation: CheckedContinuation<Void, Error>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestAuthorization() {
        guard manager.authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    var isAuthorized: Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    /// Waits for the user to respond to the location prompt, then fetches one fix.
    func getCurrentLocation() async throws -> CLLocation {
        try await waitForAuthorizationIfNeeded()
        return try await fetchSingleLocation()
    }

    private func waitForAuthorizationIfNeeded() async throws {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return
        case .denied, .restricted:
            throw LocationError.notAuthorized
        case .notDetermined:
            Self.log.info("Requesting when-in-use location authorization")
            try await withCheckedThrowingContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        @unknown default:
            throw LocationError.notAuthorized
        }
    }

    private func fetchSingleLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(20))
                guard let cont = self.locationContinuation else { return }
                self.locationContinuation = nil
                Self.log.error("Location request timed out")
                cont.resume(throwing: LocationError.timeout)
            }
        }
    }

    private func finishLocation(with result: Result<CLLocation, Error>) {
        guard let cont = locationContinuation else { return }
        locationContinuation = nil
        switch result {
        case .success(let location):
            Self.log.info("Location OK: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            cont.resume(returning: location)
        case .failure(let error):
            Self.log.error("Location failed: \(error.localizedDescription, privacy: .public)")
            cont.resume(throwing: error)
        }
    }

    private func finishAuthorization(with result: Result<Void, Error>) {
        guard let cont = authorizationContinuation else { return }
        authorizationContinuation = nil
        switch result {
        case .success:
            cont.resume()
        case .failure(let error):
            cont.resume(throwing: error)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                finishAuthorization(with: .success(()))
            case .denied, .restricted:
                finishAuthorization(with: .failure(LocationError.notAuthorized))
            case .notDetermined:
                break
            @unknown default:
                finishAuthorization(with: .failure(LocationError.notAuthorized))
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            finishLocation(with: .success(location))
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            finishLocation(with: .failure(error))
        }
    }
}
