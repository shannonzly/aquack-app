//
//  VolumePreferences.swift
//  Aquack
//
//  Display units and the daily water-count reset boundary.
//

import Foundation
import SwiftUI

enum VolumeUnit: String, CaseIterable, Identifiable {
    case ounces = "oz"
    case milliliters = "ml"

    var id: String { rawValue }

    var abbreviation: String { rawValue }

    var displayName: String {
        switch self {
        case .ounces: return "Ounces (oz)"
        case .milliliters: return "Milliliters (ml)"
        }
    }

    /// Common conversion used for display and logging.
    static let millilitersPerOunce = 29.5735

    static var current: VolumeUnit {
        let raw = UserDefaults.standard.string(forKey: AppStorageKey.volumeUnit) ?? VolumeUnit.ounces.rawValue
        return VolumeUnit(rawValue: raw) ?? .ounces
    }

    func fromOunces(_ ounces: Double) -> Double {
        switch self {
        case .ounces: return ounces
        case .milliliters: return ounces * Self.millilitersPerOunce
        }
    }

    func toOunces(_ value: Double) -> Double {
        switch self {
        case .ounces: return value
        case .milliliters: return value / Self.millilitersPerOunce
        }
    }

    /// Whole-number display for goals / progress (rounds ml, keeps oz as-is).
    func displayAmount(fromOunces ounces: Double) -> Int {
        Int(fromOunces(ounces).rounded())
    }

    func displayString(fromOunces ounces: Double) -> String {
        "\(displayAmount(fromOunces: ounces))"
    }
}

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case fahrenheit = "F"
    case celsius = "C"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .fahrenheit: return "°F"
        case .celsius: return "°C"
        }
    }

    var displayName: String {
        switch self {
        case .fahrenheit: return "Fahrenheit (°F)"
        case .celsius: return "Celsius (°C)"
        }
    }

    static var current: TemperatureUnit {
        let raw = UserDefaults.standard.string(forKey: AppStorageKey.temperatureUnit)
            ?? TemperatureUnit.fahrenheit.rawValue
        return TemperatureUnit(rawValue: raw) ?? .fahrenheit
    }

    func fromFahrenheit(_ fahrenheit: Double) -> Double {
        switch self {
        case .fahrenheit: return fahrenheit
        case .celsius: return (fahrenheit - 32) * 5 / 9
        }
    }

    func displayAmount(fromFahrenheit fahrenheit: Double) -> Int {
        Int(fromFahrenheit(fahrenheit).rounded())
    }

    func displayString(fromFahrenheit fahrenheit: Double) -> String {
        "\(displayAmount(fromFahrenheit: fahrenheit))\(symbol)"
    }
}

enum WeightUnit: String, CaseIterable, Identifiable {
    case pounds = "lb"
    case kilograms = "kg"

    var id: String { rawValue }

    var abbreviation: String { rawValue }

    var displayName: String {
        switch self {
        case .pounds: return "Pounds (lb)"
        case .kilograms: return "Kilograms (kg)"
        }
    }

    static let kilogramsPerPound = 0.45359237

    static var current: WeightUnit {
        let raw = UserDefaults.standard.string(forKey: AppStorageKey.weightUnit)
            ?? WeightUnit.pounds.rawValue
        return WeightUnit(rawValue: raw) ?? .pounds
    }

    func fromPounds(_ pounds: Double) -> Double {
        switch self {
        case .pounds: return pounds
        case .kilograms: return pounds * Self.kilogramsPerPound
        }
    }

    func toPounds(_ value: Double) -> Double {
        switch self {
        case .pounds: return value
        case .kilograms: return value / Self.kilogramsPerPound
        }
    }

    func displayAmount(fromPounds pounds: Double) -> Int {
        Int(fromPounds(pounds).rounded())
    }

    func displayString(fromPounds pounds: Double) -> String {
        let value = fromPounds(pounds)
        if abs(value.rounded() - value) < 0.05 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }

    /// UI binding: stored text is always pounds; field shows/edits in the selected unit.
    static func displayBinding(storedPounds: Binding<String>) -> Binding<String> {
        Binding(
            get: {
                let unit = WeightUnit.current
                let raw = storedPounds.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let pounds = Double(raw), pounds > 0 else { return raw }
                return unit.displayString(fromPounds: pounds)
            },
            set: { newValue in
                let unit = WeightUnit.current
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let entered = Double(trimmed), entered > 0 else {
                    storedPounds.wrappedValue = trimmed
                    return
                }
                let pounds = unit.toPounds(entered)
                if abs(pounds.rounded() - pounds) < 0.05 {
                    storedPounds.wrappedValue = "\(Int(pounds.rounded()))"
                } else {
                    storedPounds.wrappedValue = String(format: "%.1f", pounds)
                }
            }
        )
    }
}

enum DailyResetPreference {
    /// Minutes past local midnight when the water count resets (0 = midnight).
    static var minutesPastMidnight: Int {
        let stored = UserDefaults.standard.object(forKey: AppStorageKey.dailyResetMinutes) as? Int
        let value = stored ?? 0
        return max(0, min(value, (24 * 60) - 1))
    }

    static var hour: Int { minutesPastMidnight / 60 }
    static var minute: Int { minutesPastMidnight % 60 }

    /// Start of the current hydration day for `now`.
    static func dayStart(for now: Date = .now, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.nanosecond = 0
        guard let todaysReset = calendar.date(from: components) else {
            return calendar.startOfDay(for: now)
        }
        if now >= todaysReset {
            return todaysReset
        }
        return calendar.date(byAdding: .day, value: -1, to: todaysReset) ?? todaysReset
    }

    /// Hydration-day bucket key for habit grouping / charts.
    static func dayBucket(for date: Date, calendar: Calendar = .current) -> Date {
        dayStart(for: date, calendar: calendar)
    }

    static func dateBinding(minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                let cal = Calendar.current
                var comps = cal.dateComponents([.year, .month, .day], from: Date())
                let clamped = max(0, min(minutes.wrappedValue, (24 * 60) - 1))
                comps.hour = clamped / 60
                comps.minute = clamped % 60
                comps.second = 0
                return cal.date(from: comps) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                minutes.wrappedValue = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            }
        )
    }
}
