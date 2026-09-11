//
//  AppIntent.swift
//  waterwidget — quick-log from Home Screen widgets and Lock Screen Controls.
//

import AppIntents
import WidgetKit

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log water"
    static var description = IntentDescription("Add a drink toward today’s Aquack goal.")

    /// Runs in place — no unlock / no app launch (needed for Lock Screen Controls).
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Ounces")
    var ounces: Double

    init() {
        self.ounces = WidgetSnapshotStore.load().primaryLogOz
    }

    init(ounces: Double) {
        self.ounces = ounces
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let amount = ounces > 0 ? ounces : WidgetSnapshotStore.load().primaryLogOz
        guard amount > 0 else {
            return .result(dialog: "Nothing to log.")
        }
        let snapshot = WidgetSnapshotStore.logFromWidget(ounces: amount)
        WidgetCenter.shared.reloadAllTimelines()
        let shown = snapshot.displayAmount(fromOunces: amount)
        return .result(dialog: "Logged \(shown) \(snapshot.unitLabel).")
    }
}
