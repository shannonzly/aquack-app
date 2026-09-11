//
//  WidgetSnapshotStore.swift
//  Shared between Aquack and waterwidgetExtension via App Group.
//

import Foundation

struct WidgetShortcut: Codable, Equatable, Identifiable {
    var id: String { "\(name)-\(ounces)" }
    var name: String
    var ounces: Double
}

struct WidgetPendingLog: Codable, Equatable {
    var ounces: Double
    var date: Date
}

struct WidgetSnapshot: Equatable {
    var goalOz: Double
    var intakeOz: Double
    var volumeUnitRaw: String
    var primaryLogOz: Double
    var shortcuts: [WidgetShortcut]

    var progress: Double {
        guard goalOz > 0 else { return 0 }
        return min(max(intakeOz / goalOz, 0), 1)
    }

    var percent: Int { Int((progress * 100).rounded()) }

    static let empty = WidgetSnapshot(
        goalOz: 64,
        intakeOz: 0,
        volumeUnitRaw: "oz",
        primaryLogOz: 8,
        shortcuts: [
            WidgetShortcut(name: "Glass", ounces: 8),
            WidgetShortcut(name: "Bottle", ounces: 16),
            WidgetShortcut(name: "Coffee", ounces: 6)
        ]
    )

    func displayAmount(fromOunces ounces: Double) -> Int {
        if volumeUnitRaw == "ml" {
            return Int((ounces * 29.5735).rounded())
        }
        return Int(ounces.rounded())
    }

    var unitLabel: String { volumeUnitRaw == "ml" ? "ml" : "oz" }
}

enum WidgetSnapshotStore {
    static let appGroupID = "group.com.xiaomingli.aquack"

    private enum Key {
        static let goalOz = "widget.goalOz"
        static let intakeOz = "widget.intakeOz"
        static let volumeUnit = "widget.volumeUnit"
        static let primaryLogOz = "widget.primaryLogOz"
        static let shortcuts = "widget.shortcuts"
        static let pendingLogs = "widget.pendingLogs"
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func load() -> WidgetSnapshot {
        let d = defaults
        let shortcuts: [WidgetShortcut]
        if let data = d.data(forKey: Key.shortcuts),
           let decoded = try? JSONDecoder().decode([WidgetShortcut].self, from: data),
           !decoded.isEmpty {
            shortcuts = decoded
        } else {
            shortcuts = WidgetSnapshot.empty.shortcuts
        }

        let goal = d.object(forKey: Key.goalOz) as? Double ?? 64
        let intake = d.object(forKey: Key.intakeOz) as? Double ?? 0
        let primary = d.object(forKey: Key.primaryLogOz) as? Double ?? 8
        let unit = d.string(forKey: Key.volumeUnit) ?? "oz"

        return WidgetSnapshot(
            goalOz: max(1, goal),
            intakeOz: max(0, intake),
            volumeUnitRaw: unit,
            primaryLogOz: max(1, primary),
            shortcuts: Array(shortcuts.prefix(3))
        )
    }

    static func publish(
        goalOz: Double,
        intakeOz: Double,
        volumeUnitRaw: String,
        primaryLogOz: Double = 8,
        shortcuts: [WidgetShortcut]
    ) {
        let d = defaults
        d.set(max(1, goalOz), forKey: Key.goalOz)
        d.set(max(0, intakeOz), forKey: Key.intakeOz)
        d.set(volumeUnitRaw, forKey: Key.volumeUnit)
        d.set(max(1, primaryLogOz), forKey: Key.primaryLogOz)
        if let data = try? JSONEncoder().encode(Array(shortcuts.prefix(3))) {
            d.set(data, forKey: Key.shortcuts)
        }
    }

    /// Optimistic log from the widget: bump intake and queue for the app.
    @discardableResult
    static func logFromWidget(ounces: Double, at date: Date = .now) -> WidgetSnapshot {
        guard ounces > 0 else { return load() }
        var snapshot = load()
        snapshot.intakeOz += ounces
        publish(
            goalOz: snapshot.goalOz,
            intakeOz: snapshot.intakeOz,
            volumeUnitRaw: snapshot.volumeUnitRaw,
            primaryLogOz: snapshot.primaryLogOz,
            shortcuts: snapshot.shortcuts
        )

        var pending = loadPending()
        pending.append(WidgetPendingLog(ounces: ounces, date: date))
        savePending(pending)
        return snapshot
    }

    static func loadPending() -> [WidgetPendingLog] {
        guard let data = defaults.data(forKey: Key.pendingLogs),
              let decoded = try? JSONDecoder().decode([WidgetPendingLog].self, from: data) else {
            return []
        }
        return decoded
    }

    static func clearPending() {
        defaults.removeObject(forKey: Key.pendingLogs)
    }

    private static func savePending(_ logs: [WidgetPendingLog]) {
        if let data = try? JSONEncoder().encode(logs) {
            defaults.set(data, forKey: Key.pendingLogs)
        }
    }

    /// Default shortcuts: glass, bottle, first custom or coffee.
    static func makeShortcuts(custom: [(name: String, ounces: Double)]) -> [WidgetShortcut] {
        var result: [WidgetShortcut] = [
            WidgetShortcut(name: "Glass", ounces: 8),
            WidgetShortcut(name: "Bottle", ounces: 16)
        ]
        if let first = custom.first {
            result.append(WidgetShortcut(name: first.name, ounces: first.ounces))
        } else {
            result.append(WidgetShortcut(name: "Coffee", ounces: 6))
        }
        return result
    }
}

// MARK: - Theme color (app + widget)

enum ThemeColorMode: String, CaseIterable, Identifiable {
    case `default`
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .default: return "Default"
        case .custom: return "Custom"
        }
    }
}

struct ThemeRGB: Equatable {
    var r: Double
    var g: Double
    var b: Double

    static let defaultAccent = ThemeRGB(r: 0.29, g: 0.56, b: 0.92)
    static let defaultAccentSoft = ThemeRGB(r: 0.62, g: 0.80, b: 0.97)
    static let defaultWaterDeep = ThemeRGB(r: 0.28, g: 0.62, b: 0.86)
    static let defaultWaterShallow = ThemeRGB(r: 0.55, g: 0.82, b: 0.95)

    func lightened(by amount: Double) -> ThemeRGB {
        let t = min(max(amount, 0), 1)
        return ThemeRGB(
            r: r + (1 - r) * t,
            g: g + (1 - g) * t,
            b: b + (1 - b) * t
        )
    }

    func darkened(by amount: Double) -> ThemeRGB {
        let t = min(max(1 - amount, 0), 1)
        return ThemeRGB(r: r * t, g: g * t, b: b * t)
    }

    var hexString: String {
        let ri = Int((min(max(r, 0), 1) * 255).rounded())
        let gi = Int((min(max(g, 0), 1) * 255).rounded())
        let bi = Int((min(max(b, 0), 1) * 255).rounded())
        return String(format: "%02X%02X%02X", ri, gi, bi)
    }

    static func fromHex(_ hex: String) -> ThemeRGB? {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        return ThemeRGB(
            r: Double((value >> 16) & 0xFF) / 255,
            g: Double((value >> 8) & 0xFF) / 255,
            b: Double(value & 0xFF) / 255
        )
    }
}

enum ThemeColorStore {
    private enum Key {
        static let mode = "theme.mode"
        static let customHex = "theme.customHex"
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: WidgetSnapshotStore.appGroupID) ?? .standard
    }

    static var mode: ThemeColorMode {
        get {
            let raw = defaults.string(forKey: Key.mode) ?? ThemeColorMode.default.rawValue
            return ThemeColorMode(rawValue: raw) ?? .default
        }
        set { defaults.set(newValue.rawValue, forKey: Key.mode) }
    }

    static var customRGB: ThemeRGB {
        get {
            if let hex = defaults.string(forKey: Key.customHex),
               let rgb = ThemeRGB.fromHex(hex) {
                return rgb
            }
            return .defaultAccent
        }
        set { defaults.set(newValue.hexString, forKey: Key.customHex) }
    }

    static var accentRGB: ThemeRGB {
        mode == .custom ? customRGB : .defaultAccent
    }

    static var accentSoftRGB: ThemeRGB {
        mode == .custom ? customRGB.lightened(by: 0.5) : .defaultAccentSoft
    }

    static var waterDeepRGB: ThemeRGB {
        mode == .custom ? customRGB.darkened(by: 0.18) : .defaultWaterDeep
    }

    static var waterShallowRGB: ThemeRGB {
        mode == .custom ? customRGB.lightened(by: 0.35) : .defaultWaterShallow
    }

    static func set(mode: ThemeColorMode, custom: ThemeRGB? = nil) {
        self.mode = mode
        if let custom {
            customRGB = custom
        }
    }

    static func clear() {
        defaults.removeObject(forKey: Key.mode)
        defaults.removeObject(forKey: Key.customHex)
    }
}
