//
//  waterwidgetBundle.swift
//  waterwidget
//

import WidgetKit
import SwiftUI

@main
struct waterwidgetBundle: WidgetBundle {
    var body: some Widget {
        waterwidget()
        AquackLockWidget()
        AquackLogControl()
        AquackLogBottleControl()
    }
}
