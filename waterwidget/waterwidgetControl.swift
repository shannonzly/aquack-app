//
//  waterwidgetControl.swift
//  Lock Screen / Control Center control — logs water without unlocking.
//

import AppIntents
import SwiftUI
import WidgetKit

/// Lock Screen Controls can run App Intents without unlocking. Accessory widgets cannot.
struct AquackLogControl: ControlWidget {
    static let kind = "com.xiaomingli.aquack.waterwidget.log"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LogWaterIntent()) {
                Label("Log water", systemImage: "drop.fill")
            }
        }
        .displayName("Log water")
        .description("Add your usual drink amount without unlocking.")
    }
}

/// Optional second control for a larger pour (bottle).
struct AquackLogBottleControl: ControlWidget {
    static let kind = "com.xiaomingli.aquack.waterwidget.log.bottle"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LogWaterIntent(ounces: 16)) {
                Label("Log bottle", systemImage: "waterbottle.fill")
            }
        }
        .displayName("Log bottle")
        .description("Add a bottle (16 oz) without unlocking.")
    }
}
