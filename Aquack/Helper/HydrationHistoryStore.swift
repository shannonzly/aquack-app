//
//  HydrationHistoryStore.swift
//  Aquack
//

import Foundation
import SwiftData

enum HydrationHistoryStore {

    @discardableResult
    static func log(
        ounces: Double,
        context: ModelContext,
        at date: Date = .now,
        source: String = "manual",
        note: String? = nil
    ) -> HydrationLogEntry? {
        guard ounces > 0 else { return nil }
        let entry = HydrationLogEntry(timestamp: date, ounces: ounces, source: source, note: note)
        context.insert(entry)
        try? context.save()
        return entry
    }

    static func todayIntakeOz(context: ModelContext, now: Date = .now) -> Double {
        let start = DailyResetPreference.dayStart(for: now)
        let descriptor = FetchDescriptor<HydrationLogEntry>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp <= now }
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        return entries.reduce(0) { $0 + $1.ounces }
    }

    static func recentEntries(
        limit: Int = 3,
        context: ModelContext,
        now: Date = .now
    ) -> [HydrationLogEntry] {
        guard limit > 0 else { return [] }
        let start = DailyResetPreference.dayStart(for: now)
        var descriptor = FetchDescriptor<HydrationLogEntry>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp <= now },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    static func delete(_ entry: HydrationLogEntry, context: ModelContext) {
        context.delete(entry)
        try? context.save()
    }

    @discardableResult
    static func deleteLatest(context: ModelContext, now: Date = .now) -> Bool {
        guard let latest = recentEntries(limit: 1, context: context, now: now).first else {
            return false
        }
        delete(latest, context: context)
        return true
    }

    static func entriesForLastDays(
        _ days: Int,
        context: ModelContext,
        now: Date = .now
    ) -> [HydrationLogEntry] {
        guard days > 0 else { return [] }
        let currentStart = DailyResetPreference.dayStart(for: now)
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: currentStart) ?? now
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
