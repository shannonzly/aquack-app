//
//  LogWhenPreset.swift
//  Aquack
//

import Foundation

enum LogWhenPreset: String, CaseIterable, Identifiable {
    case justNow
    case oneHourAgo
    case threeHoursAgo
    case thisMorning
    case thisAfternoon
    case thisEvening
    case selectTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .justNow: return "Just now"
        case .oneHourAgo: return "~1h ago"
        case .threeHoursAgo: return "~3h ago"
        case .thisMorning: return "This morning"
        case .thisAfternoon: return "This afternoon"
        case .thisEvening: return "This evening"
        case .selectTime: return "Select time"
        }
    }

    /// Resolves a timestamp within the current hydration day, never after `now`.
    func date(now: Date = .now, selectedTime: Date? = nil, calendar: Calendar = .current) -> Date {
        let dayStart = DailyResetPreference.dayStart(for: now, calendar: calendar)
        let clamp: (Date) -> Date = { date in
            min(max(date, dayStart), now)
        }

        switch self {
        case .justNow:
            return now
        case .oneHourAgo:
            return clamp(now.addingTimeInterval(-3600))
        case .threeHoursAgo:
            return clamp(now.addingTimeInterval(-3 * 3600))
        case .thisMorning:
            return clamp(Self.anchor(hour: 9, minute: 0, onSameCalendarDayAs: now, calendar: calendar, dayStart: dayStart))
        case .thisAfternoon:
            return clamp(Self.anchor(hour: 14, minute: 0, onSameCalendarDayAs: now, calendar: calendar, dayStart: dayStart))
        case .thisEvening:
            return clamp(Self.anchor(hour: 19, minute: 0, onSameCalendarDayAs: now, calendar: calendar, dayStart: dayStart))
        case .selectTime:
            return clamp(selectedTime ?? now)
        }
    }

    private static func anchor(
        hour: Int,
        minute: Int,
        onSameCalendarDayAs now: Date,
        calendar: Calendar,
        dayStart: Date
    ) -> Date {
        // Prefer the calendar day of `now`, but if that lands before the hydration day
        // start (e.g. reset at 4 AM and it's 2 AM), use the day that contains dayStart.
        var comps = calendar.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        if let candidate = calendar.date(from: comps), candidate >= dayStart {
            return candidate
        }
        var startComps = calendar.dateComponents([.year, .month, .day], from: dayStart)
        startComps.hour = hour
        startComps.minute = minute
        startComps.second = 0
        return calendar.date(from: startComps) ?? dayStart
    }
}
