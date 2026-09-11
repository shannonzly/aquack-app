//
//  WidgetSnapshotSync.swift
//  Aquack — publish snapshot + flush widget pending logs into SwiftData.
//

import Foundation
import SwiftData
import WidgetKit

enum WidgetSnapshotSync {

    @MainActor
    static func publish(goalOz: Int, intakeOz: Double) {
        let customs = CustomDrinkSizeStore.load().map { (name: $0.name, ounces: $0.ounces) }
        let shortcuts = WidgetSnapshotStore.makeShortcuts(custom: customs)
        let unit = UserDefaults.standard.string(forKey: AppStorageKey.volumeUnit) ?? "oz"
        WidgetSnapshotStore.publish(
            goalOz: Double(max(1, goalOz)),
            intakeOz: max(0, intakeOz),
            volumeUnitRaw: unit,
            primaryLogOz: 8,
            shortcuts: shortcuts
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    @MainActor
    static func publishFromContext(context: ModelContext, goalOz: Int) {
        let intake = HydrationHistoryStore.todayIntakeOz(context: context)
        publish(goalOz: goalOz, intakeOz: intake)
    }

    /// Move widget-queued drinks into SwiftData, then republish truth.
    @MainActor
    static func flushPendingLogs(context: ModelContext, goalOz: Int) {
        let pending = WidgetSnapshotStore.loadPending()
        guard !pending.isEmpty else {
            publishFromContext(context: context, goalOz: goalOz)
            return
        }
        for log in pending {
            HydrationHistoryStore.log(
                ounces: log.ounces,
                context: context,
                at: log.date,
                source: "widget"
            )
        }
        WidgetSnapshotStore.clearPending()
        publishFromContext(context: context, goalOz: goalOz)
    }
}
