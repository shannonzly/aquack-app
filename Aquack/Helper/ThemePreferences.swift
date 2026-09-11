//
//  ThemePreferences.swift
//  Aquack — app-side theme resolution + widget sync.
//

import SwiftUI
import UIKit
import WidgetKit

enum ThemePreferences {
    static var accent: Color { color(ThemeColorStore.accentRGB) }
    static var accentSoft: Color { color(ThemeColorStore.accentSoftRGB) }
    static var waterDeep: Color { color(ThemeColorStore.waterDeepRGB) }
    static var waterShallow: Color { color(ThemeColorStore.waterShallowRGB) }

    private static var widgetReloadTask: Task<Void, Never>?

    static func color(_ rgb: ThemeRGB) -> Color {
        Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    /// Persist selection, bump revision for SwiftUI refresh, reload widgets.
    static func apply(mode: ThemeColorMode, custom: Color? = nil, revision: Binding<Int>? = nil) {
        if let custom {
            ThemeColorStore.set(mode: mode, custom: rgb(from: custom))
        } else {
            ThemeColorStore.set(mode: mode)
        }
        if let revision {
            revision.wrappedValue += 1
        }
        scheduleWidgetReload()
    }

    static func rgb(from color: Color) -> ThemeRGB {
        let ui = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return .defaultAccent
        }
        return ThemeRGB(r: Double(r), g: Double(g), b: Double(b))
    }

    private static func scheduleWidgetReload() {
        widgetReloadTask?.cancel()
        widgetReloadTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
