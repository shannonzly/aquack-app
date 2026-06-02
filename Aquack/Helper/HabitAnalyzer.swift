//
//  HabitAnalyzer.swift
//  Aquack
//

import Foundation
import SwiftData

struct HabitProfile: Equatable {
    var daysAnalyzed: Int
    var averageDailyIntakeOz: Double
    var averageLogsPerDay: Double
    var mostCommonHours: [Int]
    var longestGapHours: Double
    var consistencyScore: Double

    static let empty = HabitProfile(
        daysAnalyzed: 0,
        averageDailyIntakeOz: 0,
        averageLogsPerDay: 0,
        mostCommonHours: [],
        longestGapHours: 0,
        consistencyScore: 0
    )
}

enum HabitAnalyzer {

    static func analyze(context: ModelContext, goalOz: Int) -> HabitProfile {
        let entries = HydrationHistoryStore.entriesForLastDays(14, context: context)
        guard !entries.isEmpty else { return .empty }

        let grouped = Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.timestamp) }
        let dayCount = max(grouped.count, 1)
        let totalOz = entries.reduce(0) { $0 + $1.ounces }
        let averageDaily = totalOz / Double(dayCount)
        let averageLogs = Double(entries.count) / Double(dayCount)

        var hourCounts: [Int: Int] = [:]
        for entry in entries {
            let hour = Calendar.current.component(.hour, from: entry.timestamp)
            hourCounts[hour, default: 0] += 1
        }
        let commonHours = hourCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(3)
            .map(\.key)

        let sortedTimes = entries.map(\.timestamp).sorted()
        var longestGap: TimeInterval = 0
        for idx in 1..<sortedTimes.count {
            longestGap = max(longestGap, sortedTimes[idx].timeIntervalSince(sortedTimes[idx - 1]))
        }

        let goal = max(goalOz, 1)
        let adherence = min(1.25, averageDaily / Double(goal))
        let cadence = min(1.0, averageLogs / 6.0)
        let consistency = max(0, min(1, (adherence * 0.7) + (cadence * 0.3)))

        return HabitProfile(
            daysAnalyzed: dayCount,
            averageDailyIntakeOz: averageDaily,
            averageLogsPerDay: averageLogs,
            mostCommonHours: commonHours,
            longestGapHours: longestGap / 3600,
            consistencyScore: consistency
        )
    }

    static func habitAdjustmentOz(for profile: HabitProfile) -> Int {
        guard profile.daysAnalyzed >= 3 else { return 0 }

        switch profile.consistencyScore {
        case ..<0.45:
            return -6
        case 0.45..<0.65:
            return -2
        case 0.65..<0.9:
            return 2
        default:
            return 4
        }
    }
}

