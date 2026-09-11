//
//  waterwidget.swift
//  Aquack progress ring + quick-log (Home Screen interactive, Lock Screen accessory).
//

import AppIntents
import SwiftUI
import WidgetKit

enum AquackWidgetURL {
    static let scheme = "aquack"

    static func log(ounces: Double) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "log"
        components.queryItems = [
            URLQueryItem(name: "ounces", value: String(ounces))
        ]
        return components.url ?? URL(string: "aquack://log")!
    }
}

struct AquackWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct AquackWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AquackWidgetEntry {
        AquackWidgetEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (AquackWidgetEntry) -> Void) {
        completion(AquackWidgetEntry(date: .now, snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AquackWidgetEntry>) -> Void) {
        let entry = AquackWidgetEntry(date: .now, snapshot: WidgetSnapshotStore.load())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Home Screen (interactive)

struct AquackHomeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: AquackWidgetEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumHome
            default:
                smallHome
            }
        }
        .containerBackground(for: .widget) {
            WidgetPalette.background
        }
    }

    private var smallHome: some View {
        ZStack {
            WidgetProgressRing(progress: snapshot.progress, lineWidth: 10)
            Button(intent: LogWaterIntent(ounces: snapshot.primaryLogOz)) {
                VStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("\(snapshot.percent)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("+\(snapshot.displayAmount(fromOunces: snapshot.primaryLogOz))")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .opacity(0.85)
                }
                .foregroundStyle(WidgetPalette.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private var mediumHome: some View {
        HStack(spacing: 16) {
            ZStack {
                WidgetProgressRing(progress: snapshot.progress, lineWidth: 12)
                VStack(spacing: 2) {
                    Text("\(snapshot.percent)%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetPalette.accent)
                    Text("\(snapshot.displayAmount(fromOunces: snapshot.intakeOz))/\(snapshot.displayAmount(fromOunces: snapshot.goalOz))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(WidgetPalette.label)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                ForEach(snapshot.shortcuts) { shortcut in
                    Button(intent: LogWaterIntent(ounces: shortcut.ounces)) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text(shortcutLabel(shortcut))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(WidgetPalette.title)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(WidgetPalette.chip, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func shortcutLabel(_ shortcut: WidgetShortcut) -> String {
        "\(shortcut.name) · \(snapshot.displayAmount(fromOunces: shortcut.ounces)) \(snapshot.unitLabel)"
    }
}

// MARK: - Lock Screen (accessory — tap opens app via widgetURL; Lock Screen widgets are not interactive)

struct AquackLockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: AquackWidgetEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                lockRectangular
            case .accessoryInline:
                lockInline
            default:
                lockCircular
            }
        }
        .widgetURL(AquackWidgetURL.log(ounces: snapshot.primaryLogOz))
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
    }

    private var lockCircular: some View {
        ZStack {
            WidgetProgressRing(progress: snapshot.progress, lineWidth: 5, trackOpacity: 0.25)
            VStack(spacing: 0) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("\(snapshot.percent)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
        }
        .accessibilityLabel("Aquack \(snapshot.percent) percent. Tap to log water.")
    }

    private var lockRectangular: some View {
        HStack(spacing: 10) {
            WidgetProgressRing(progress: snapshot.progress, lineWidth: 4, trackOpacity: 0.25)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Aquack")
                    .font(.headline)
                Text("\(snapshot.percent)% · \(snapshot.displayAmount(fromOunces: snapshot.intakeOz))/\(snapshot.displayAmount(fromOunces: snapshot.goalOz)) \(snapshot.unitLabel)")
                    .font(.caption2)
                Text("Tap +\(snapshot.displayAmount(fromOunces: snapshot.primaryLogOz)) \(snapshot.unitLabel)")
                    .font(.caption2)
            }
            Spacer(minLength: 0)
            Image(systemName: "drop.fill")
                .font(.title3)
        }
        .accessibilityLabel("Aquack \(snapshot.percent) percent. Tap to log water.")
    }

    private var lockInline: some View {
        Text("Aquack \(snapshot.percent)% · +\(snapshot.displayAmount(fromOunces: snapshot.primaryLogOz))\(snapshot.unitLabel)")
    }
}

// MARK: - Shared UI

private struct WidgetProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat
    var trackOpacity: Double = 0.35

    var body: some View {
        ZStack {
            Circle()
                .stroke(WidgetPalette.accentSoft.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    WidgetPalette.accent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .padding(4)
    }
}

private enum WidgetPalette {
    private static func color(_ rgb: ThemeRGB) -> Color {
        Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    static var accent: Color { color(ThemeColorStore.accentRGB) }
    static var accentSoft: Color { color(ThemeColorStore.accentSoftRGB) }
    static let title = Color(red: 0.12, green: 0.22, blue: 0.38)
    static let label = Color(red: 0.35, green: 0.45, blue: 0.58)
    static var chip: Color { accentSoft.opacity(0.35) }
    static var background: Color {
        let soft = ThemeColorStore.accentSoftRGB.lightened(by: 0.55)
        return color(soft)
    }
}

// MARK: - Widget definitions

struct waterwidget: Widget {
    let kind: String = "com.xiaomingli.aquack.waterwidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AquackWidgetProvider()) { entry in
            AquackHomeWidgetView(entry: entry)
        }
        .configurationDisplayName("Aquack")
        .description("Progress ring and one-tap water logging on the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AquackLockWidget: Widget {
    let kind: String = "com.xiaomingli.aquack.waterwidget.lock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AquackWidgetProvider()) { entry in
            AquackLockWidgetView(entry: entry)
        }
        .configurationDisplayName("Aquack")
        .description("Hydration progress on the Lock Screen. For logging without unlocking, add the Log water Control.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

#Preview("Home Small", as: .systemSmall) {
    waterwidget()
} timeline: {
    AquackWidgetEntry(date: .now, snapshot: .empty)
}

#Preview("Lock Circular", as: .accessoryCircular) {
    AquackLockWidget()
} timeline: {
    AquackWidgetEntry(
        date: .now,
        snapshot: WidgetSnapshot(
            goalOz: 64,
            intakeOz: 24,
            volumeUnitRaw: "oz",
            primaryLogOz: 8,
            shortcuts: WidgetSnapshot.empty.shortcuts
        )
    )
}
