//
//  AquackApp.swift
//  Aquack
//

import SwiftData
import SwiftUI

@MainActor
final class Change: ObservableObject {
    @Published var goalAmount: String { didSet { save(goalAmount, key: "goalAmount") } }
    @Published var recommendedAmount: String { didSet { save(recommendedAmount, key: "recommendedAmount") } }
    @Published var dailyIntake: String { didSet { save(dailyIntake, key: "dailyIntake") } }
    @Published var height: String { didSet { save(height, key: "height") } }
    @Published var weight: String { didSet { save(weight, key: "weight") } }
    @Published var age: String { didSet { save(age, key: "age") } }
    @Published var gender: UserInfo.Gender { didSet { save(gender.rawValue, key: "gender") } }
    @Published var activityLevel: UserInfo.ActivityLevel { didSet { save(activityLevel.rawValue, key: "activityLevel") } }
    @Published var climate: UserInfo.Climate { didSet { save(climate.rawValue, key: "climate") } }
    @Published var usingRec: Bool { didSet { UserDefaults.standard.set(usingRec, forKey: "usingRec") } }
    @Published var lastStepsToday: Double { didSet { UserDefaults.standard.set(lastStepsToday, forKey: "lastStepsToday") } }
    @Published var lastWeatherTempF: Double? {
        didSet {
            if let lastWeatherTempF {
                UserDefaults.standard.set(lastWeatherTempF, forKey: "lastWeatherTempF")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastWeatherTempF")
            }
        }
    }

    init() {
        let defaults = UserDefaults.standard
        goalAmount = defaults.string(forKey: "goalAmount") ?? "64"
        recommendedAmount = defaults.string(forKey: "recommendedAmount") ?? "64"
        dailyIntake = defaults.object(forKey: "dailyIntake") != nil ? "\(Int(defaults.double(forKey: "dailyIntake")))" : "0"
        height = defaults.string(forKey: "height") ?? ProfileDefaults.heightCm
        weight = defaults.string(forKey: "weight") ?? ProfileDefaults.weightLb
        age = defaults.string(forKey: "age") ?? ProfileDefaults.age
        gender = UserInfo.Gender(rawValue: defaults.string(forKey: "gender") ?? "") ?? ProfileDefaults.gender
        activityLevel = UserInfo.ActivityLevel(rawValue: defaults.string(forKey: "activityLevel") ?? "") ?? ProfileDefaults.activityLevel
        climate = UserInfo.Climate(rawValue: defaults.string(forKey: "climate") ?? "") ?? ProfileDefaults.climate
        usingRec = defaults.object(forKey: "usingRec") as? Bool ?? true
        lastStepsToday = defaults.double(forKey: "lastStepsToday")
        if defaults.object(forKey: "lastWeatherTempF") != nil {
            lastWeatherTempF = defaults.double(forKey: "lastWeatherTempF")
        } else {
            lastWeatherTempF = nil
        }
    }

    private func save(_ value: String, key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

struct RootView: View {
    @EnvironmentObject var rec: Change
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("didFinishTutorial") private var didFinishTutorial = false
    @AppStorage(AppStorageKey.themeRevision) private var themeRevision = 0

    var body: some View {
        Group {
            if didFinishTutorial {
                ContentView()
            } else {
                TutorialView(didFinishTutorial: $didFinishTutorial)
            }
        }
        .animation(nil, value: themeRevision)
        .tint(HydrationTheme.accent)
        .preferredColorScheme(.light)
        .task {
            HydrationHistoryStore.migrateLegacyDailyIntakeIfNeeded(context: modelContext)
            WidgetSnapshotSync.flushPendingLogs(
                context: modelContext,
                goalOz: rec.goalAmount.ozAmountInt
            )
            await WeatherManager.shared.loadAttributionIfNeeded()
            await HydrationSync.refresh(recommendation: rec, modelContext: modelContext)
            WidgetSnapshotSync.publishFromContext(
                context: modelContext,
                goalOz: rec.goalAmount.ozAmountInt
            )
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            WidgetSnapshotSync.flushPendingLogs(
                context: modelContext,
                goalOz: rec.goalAmount.ozAmountInt
            )
            Task {
                await HydrationSync.refresh(recommendation: rec, modelContext: modelContext, force: true)
                WidgetSnapshotSync.publishFromContext(
                    context: modelContext,
                    goalOz: rec.goalAmount.ozAmountInt
                )
            }
        }
        .onOpenURL { url in
            handleWidgetURL(url)
        }
    }

    private func handleWidgetURL(_ url: URL) {
        guard url.scheme == "aquack", url.host == "log" else { return }
        let ounces: Double = {
            guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                  let raw = items.first(where: { $0.name == "ounces" })?.value,
                  let value = Double(raw), value > 0 else {
                return 8
            }
            return value
        }()
        WidgetSnapshotSync.flushPendingLogs(
            context: modelContext,
            goalOz: rec.goalAmount.ozAmountInt
        )
        HydrationHistoryStore.log(ounces: ounces, context: modelContext, source: "widget")
        WidgetSnapshotSync.publishFromContext(
            context: modelContext,
            goalOz: rec.goalAmount.ozAmountInt
        )
    }
}

@main
struct AquackApp: App {
    @StateObject private var rec = Change()

    private let modelContainer: ModelContainer = {
        let schema = Schema([HydrationLogEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    init() {
        AppLaunchDefaults.register()
        NotificationManager.shared.configureDelegate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(rec)
        }
        .modelContainer(modelContainer)
    }
}

