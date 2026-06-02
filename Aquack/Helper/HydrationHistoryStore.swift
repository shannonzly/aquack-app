//
//  HydrationHistoryStore.swift
//  Aquack
//

import Foundation
import SwiftData

enum HydrationHistoryStore {

    static func log(
        ounces: Double,
        context: ModelContext,
        at date: Date = .now,
        source: String = "manual"
    ) {
        guard ounces > 0 else { return }
        let entry = HydrationLogEntry(timestamp: date, ounces: ounces, source: source)
        context.insert(entry)
        try? context.save()
    }

    static func todayIntakeOz(context: ModelContext, now: Date = .now) -> Double {
        let start = Calendar.current.startOfDay(for: now)
        let descriptor = FetchDescriptor<HydrationLogEntry>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp <= now }
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        return entries.reduce(0) { $0 + $1.ounces }
    }

    static func entriesForLastDays(
        _ days: Int,
        context: ModelContext,
        now: Date = .now
    ) -> [HydrationLogEntry] {
        guard days > 0 else { return [] }
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: now)) ?? now
        let descriptor = FetchDescriptor<HydrationLogEntry>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp <= now },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func migrateLegacyDailyIntakeIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "didMigrateLegacyIntake"),
              defaults.object(forKey: "dailyIntake") != nil else {
            return
        }

        let legacy = defaults.double(forKey: "dailyIntake")
        if legacy > 0 {
            log(ounces: legacy, context: context, at: .now, source: "legacy")
        }
        defaults.set(true, forKey: "didMigrateLegacyIntake")
    }
}

