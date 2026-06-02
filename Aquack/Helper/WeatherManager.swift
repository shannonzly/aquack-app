//
//  WeatherManager.swift
//  Aquack
//
//  Created by Shannon Zhang on 3/2/26.
//

import CoreLocation
import Foundation
import OSLog
import WeatherKit

/// Current temperature via Apple WeatherKit (requires WeatherKit on the App ID and in App Services).
@MainActor
final class WeatherManager {

    static let shared = WeatherManager()

    private let service = WeatherService.shared
    private static let log = Logger(subsystem: "com.xiaomingli.aquack", category: "Weather")

    private init() {}

    func fetchCurrentTemperature(for location: CLLocation) async throws -> Double {
        let current = try await service.weather(for: location, including: .current)
        let temp = current.temperature.converted(to: UnitTemperature.fahrenheit).value
        Self.log.info("WeatherKit OK: \(temp, privacy: .public)°F")
        return temp
    }
}
