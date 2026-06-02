//
//  ClimateTemperature.swift
//  Aquack
//
//  Free fallback when live weather is unavailable.
//

import Foundation

enum ClimateTemperature {

    static func estimatedFahrenheit(for climate: UserInfo.Climate) -> Double {
        switch climate {
        case .tropical: return 88
        case .temperate: return 70
        case .cold: return 45
        }
    }
}

enum TemperatureSource {
    case liveWeather
    case climateEstimate
}

enum TemperatureResolver {

    @MainActor
    static func resolve(
        for rec: Change,
        locationEnabled: Bool,
        forceRefresh: Bool = false
    ) async -> (fahrenheit: Double?, source: TemperatureSource) {
        if locationEnabled, let live = await getCurrentTemperatureFahrenheit(forceRefresh: forceRefresh) {
            return (live, .liveWeather)
        }
        return (ClimateTemperature.estimatedFahrenheit(for: rec.climate), .climateEstimate)
    }
}
