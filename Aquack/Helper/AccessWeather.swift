//
//  AccessWeather.swift
//  Aquack
//

import CoreLocation
import OSLog

private let weatherCacheMaxAge: TimeInterval = 3 * 60 * 60
/// Refetch when the device moves farther than ~5 km from the cached fix.
private let weatherCacheMaxDistanceMeters: CLLocationDistance = 5_000

private let log = Logger(subsystem: "com.xiaomingli.aquack", category: "Weather")

func setLocationWeatherEnabled(_ enabled: Bool) {
    UserDefaults.standard.set(enabled, forKey: AppStorageKey.locationWeatherEnabled)
    if !enabled {
        clearWeatherCache()
    }
}

func clearWeatherCache() {
    UserDefaults.standard.removeObject(forKey: AppStorageKey.lastWeatherKitFetchDate)
    UserDefaults.standard.removeObject(forKey: AppStorageKey.cachedWeatherKitTempF)
    UserDefaults.standard.removeObject(forKey: AppStorageKey.cachedWeatherLatitude)
    UserDefaults.standard.removeObject(forKey: AppStorageKey.cachedWeatherLongitude)
}

func getCurrentTemperatureFahrenheit(forceRefresh: Bool = false) async -> Double? {
    if !forceRefresh, let cached = cachedWeatherTemperature(for: nil) {
        return cached
    }

    do {
        let location = try await LocationManager.shared.getCurrentLocation()
        if !forceRefresh, let cached = cachedWeatherTemperature(for: location) {
            return cached
        }
        let temp = try await WeatherManager.shared.fetchCurrentTemperature(for: location)
        storeWeatherTemperature(temp, location: location)
        return temp
    } catch {
        log.error("Weather fetch failed: \(error.localizedDescription, privacy: .public)")
        if forceRefresh { return nil }
        return cachedWeatherTemperature(for: nil)
    }
}

/// Returns cached °F when still fresh and (if `near` is set) close enough to that fix.
private func cachedWeatherTemperature(for near: CLLocation?) -> Double? {
    guard let fetchedAt = UserDefaults.standard.object(forKey: AppStorageKey.lastWeatherKitFetchDate) as? Date,
          Date().timeIntervalSince(fetchedAt) < weatherCacheMaxAge,
          UserDefaults.standard.object(forKey: AppStorageKey.cachedWeatherKitTempF) != nil else {
        return nil
    }

    if let near {
        let lat = UserDefaults.standard.object(forKey: AppStorageKey.cachedWeatherLatitude) as? Double
        let lon = UserDefaults.standard.object(forKey: AppStorageKey.cachedWeatherLongitude) as? Double
        if let lat, let lon {
            let cachedPoint = CLLocation(latitude: lat, longitude: lon)
            if near.distance(from: cachedPoint) > weatherCacheMaxDistanceMeters {
                return nil
            }
        }
    }

    return UserDefaults.standard.double(forKey: AppStorageKey.cachedWeatherKitTempF)
}

private func storeWeatherTemperature(_ tempF: Double, location: CLLocation) {
    UserDefaults.standard.set(Date(), forKey: AppStorageKey.lastWeatherKitFetchDate)
    UserDefaults.standard.set(tempF, forKey: AppStorageKey.cachedWeatherKitTempF)
    UserDefaults.standard.set(location.coordinate.latitude, forKey: AppStorageKey.cachedWeatherLatitude)
    UserDefaults.standard.set(location.coordinate.longitude, forKey: AppStorageKey.cachedWeatherLongitude)
}
