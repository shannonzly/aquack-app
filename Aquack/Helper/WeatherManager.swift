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
final class WeatherManager: ObservableObject {

    static let shared = WeatherManager()

    @Published private(set) var attribution: WeatherAttribution?

    private let service = WeatherService.shared
    private static let log = Logger(subsystem: "com.xiaomingli.aquack", category: "Weather")
    private var isLoadingAttribution = false

    private init() {}

    func fetchCurrentTemperature(for location: CLLocation) async throws -> Double {
        let current = try await service.weather(for: location, including: .current)
        let temp = current.temperature.converted(to: UnitTemperature.fahrenheit).value
        Self.log.info("WeatherKit OK: \(temp, privacy: .public)°F")
        return temp
    }

    func loadAttributionIfNeeded() async {
        guard attribution == nil, !isLoadingAttribution else { return }
        isLoadingAttribution = true
        defer { isLoadingAttribution = false }

        do {
            attribution = try await service.attribution
            Self.log.info("WeatherKit attribution loaded")
        } catch {
            Self.log.error("WeatherKit attribution failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Dark combined mark for Aquack's subtle light-tint badge.
    func displayMarkURL() -> URL? {
        attribution?.combinedMarkDarkURL
    }
}
