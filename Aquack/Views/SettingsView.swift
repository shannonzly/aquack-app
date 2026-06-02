//
//  SettingsView.swift
//  Aquack
//
//  Created by Shannon Zhang on 2/18/26.
//

import SwiftUI
import SwiftData

private enum StorageKey {
    static let notificationsInterval = "notificationsInterval"
    static let notificationTitle = "notificationTitle"
    static let notificationBody = "notificationBody"
    static let healthStepsEnabled = AppStorageKey.healthStepsEnabled
}


struct SettingsView: View {
    @EnvironmentObject var rec: Change
    @Environment(\.modelContext) private var modelContext

    @AppStorage(AppStorageKey.personalizedGoalEnabled) private var personalizedGoalEnabled = true
    @AppStorage(AppStorageKey.smartRemindersEnabled) private var smartRemindersEnabled = true
    @AppStorage(AppStorageKey.duckCoachEnabled) private var duckCoachEnabled = true

    @State private var selectedInterval: SettingsInfo.Interval = .one
    @State private var selectedGoal: SettingsInfo.Goal = .rec
    @State private var customGoalValue: String = ""

    @State private var notificationsEnabled = false
    @State private var notificationTitle = ""
    @State private var notificationBody = ""
    @State private var healthEnabled = false
    @State private var locationEnabled = false
    @State private var healthAuthTrigger = 0
    @AppStorage("didFinishTutorial") private var didFinishTutorial = true

    var body: some View {
        HydrationPageShell(bubbleIntensity: 0.5) {
            KeyboardDismissingScrollView {
                VStack(spacing: HomeLayout.sectionSpacing) {
                    PageHeroHeader(
                        title: "Settings",
                        subtitle: "Reminders, goals, and personalization",
                        systemImage: "gearshape.fill"
                    )

                    settingsSection(title: "Reminders", systemImage: "bell.fill") {
                        VStack(spacing: HomeLayout.cardSpacing + 4) {
                            Toggle("Enable Notifications", isOn: $notificationsEnabled)
                                .onChange(of: notificationsEnabled) { _, newValue in
                                    handleNotificationToggle(newValue)
                                }

                            if notificationsEnabled {
                                Divider()
                                GlassInsetField(label: "Reminder title", text: $notificationTitle)
                                    .onChange(of: notificationTitle) { _, _ in
                                        saveNotificationMessage()
                                        if notificationsEnabled { rescheduleNotification() }
                                    }
                                GlassInsetField(label: "Reminder message", text: $notificationBody)
                                    .onChange(of: notificationBody) { _, _ in
                                        saveNotificationMessage()
                                        if notificationsEnabled { rescheduleNotification() }
                                    }
                            }

                            Divider()

                            Toggle("Smart reminders", isOn: $smartRemindersEnabled)
                                .disabled(!notificationsEnabled)
                                .onChange(of: smartRemindersEnabled) { _, _ in
                                    if notificationsEnabled { rescheduleNotification() }
                                }

                            if !smartRemindersEnabled {
                                Picker("Reminder Frequency", selection: $selectedInterval) {
                                    ForEach(SettingsInfo.Interval.allCases) { interval in
                                        Text(interval.rawValue).tag(interval)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .disabled(!notificationsEnabled)
                                .onChange(of: selectedInterval) { _, _ in
                                    if notificationsEnabled { rescheduleNotification() }
                                }
                            } else if notificationsEnabled {
                                Text("Reminders adapt to when you usually drink.")
                                    .hydrationFootnote()
                            }
                        }
                    }

                    settingsSection(title: "Personalization", systemImage: "clock.arrow.circlepath") {
                        VStack(alignment: .leading, spacing: HomeLayout.cardSpacing + 4) {
                            Toggle("Aquack coach", isOn: $duckCoachEnabled)
                            Toggle("Adjust goal from your habits", isOn: $personalizedGoalEnabled)
                                .onChange(of: personalizedGoalEnabled) { _, _ in
                                    Task {
                                        await HydrationSync.refresh(
                                            recommendation: rec,
                                            modelContext: modelContext,
                                            force: true
                                        )
                                    }
                                }
                        }
                    }

                    settingsSection(title: "Daily Goal", systemImage: "flag.fill") {
                        VStack(spacing: HomeLayout.cardSpacing + 4) {
                            Picker("Goal Type", selection: $selectedGoal) {
                                ForEach(SettingsInfo.Goal.allCases) { goal in
                                    Text(goal.segmentedLabel).tag(goal)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: selectedGoal) { _, _ in syncGoalToRec() }

                            if selectedGoal == .custom {
                                GlassInsetField(label: "Target (oz)", text: $customGoalValue, keyboard: .numberPad)
                                    .onChange(of: customGoalValue) { _, _ in syncGoalToRec() }
                            } else {
                                Text("We'll calculate your goal based on activity and weather.")
                                    .hydrationFootnote()
                            }
                        }
                    }

                    settingsSection(title: "Personalization", systemImage: "location.fill") {
                        VStack(alignment: .leading, spacing: HomeLayout.cardSpacing + 4) {
                            stepsConnectionSection

                            Divider()

                            Toggle("Local weather", isOn: $locationEnabled)
                                .onChange(of: locationEnabled) { _, newValue in
                                    setLocationWeatherEnabled(newValue)
                                    if newValue {
                                        clearWeatherCache()
                                        LocationManager.shared.requestAuthorization()
                                    } else {
                                        rec.lastWeatherTempF = nil
                                    }
                                    Task {
                                        await HydrationSync.refresh(
                                            recommendation: rec,
                                            modelContext: modelContext,
                                            force: true
                                        )
                                    }
                                }
                        }
                    }

                    settingsSection(title: "Advanced", systemImage: "arrow.counterclockwise") {
                        Button("Reset app & show tutorial again", role: .destructive) {
                            AppReset.clearAllSavedState()
                            didFinishTutorial = false
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.red)
                    }

                }
                .hydrationPageContent()
            }
        }
        .healthKitAccessOnTrigger($healthAuthTrigger) {
            Task { await finishSettingsHealthConnect() }
        }
        .onAppear {
            loadPersistedSettings()
            Task { await refreshPermissionStates() }
        }
        .onChange(of: rec.goalAmount) { _, _ in
            if rec.usingRec { customGoalValue = rec.goalAmount }
        }
        .onChange(of: rec.usingRec) { _, _ in
            selectedGoal = rec.usingRec ? .rec : .custom
            customGoalValue = rec.goalAmount
        }
    }

    // MARK: - Load / Persist

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: HomeLayout.cardSpacing) {
            CapsuleSectionHeader(title: title, systemImage: systemImage)
            GlassCard(content: content)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadPersistedSettings() {
        if let raw = UserDefaults.standard.string(forKey: StorageKey.notificationsInterval),
           let interval = SettingsInfo.Interval(rawValue: raw) {
            selectedInterval = interval
        }
        notificationTitle = UserDefaults.standard.string(forKey: StorageKey.notificationTitle) ?? AquackCopy.defaultNotificationTitle
        notificationBody = UserDefaults.standard.string(forKey: StorageKey.notificationBody) ?? AquackCopy.defaultNotificationBody
        healthEnabled = UserDefaults.standard.bool(forKey: StorageKey.healthStepsEnabled)
        locationEnabled = UserDefaults.standard.bool(forKey: AppStorageKey.locationWeatherEnabled)
        notificationsEnabled = UserDefaults.standard.bool(forKey: AppStorageKey.notificationsUserEnabled)

        selectedGoal = rec.usingRec ? .rec : .custom
        customGoalValue = rec.goalAmount
        if customGoalValue.isEmpty { customGoalValue = "64" }
    }

    private func saveNotificationMessage() {
        UserDefaults.standard.set(notificationTitle, forKey: StorageKey.notificationTitle)
        UserDefaults.standard.set(notificationBody, forKey: StorageKey.notificationBody)
    }

    private func syncGoalToRec() {
        if selectedGoal == .rec {
            rec.usingRec = true
            rec.goalAmount = rec.recommendedAmount
        } else {
            rec.usingRec = false
            rec.goalAmount = customGoalValue.isEmpty ? "64" : customGoalValue
        }
    }

    private func refreshPermissionStates() async {
        let systemNotifGranted = await NotificationManager.shared.checkAuthorizationStatus()
        let userWantsNotifications = UserDefaults.standard.bool(forKey: AppStorageKey.notificationsUserEnabled)
        let wantsWeather = UserDefaults.standard.bool(forKey: AppStorageKey.locationWeatherEnabled)
        await MainActor.run {
            locationEnabled = wantsWeather
            healthEnabled = UserDefaults.standard.bool(forKey: StorageKey.healthStepsEnabled)
            notificationsEnabled = userWantsNotifications && systemNotifGranted
        }
        if userWantsNotifications && systemNotifGranted {
            rescheduleNotification()
        } else {
            NotificationManager.shared.cancelHydrationReminder()
        }
        if wantsWeather && LocationManager.shared.isAuthorized {
            await HydrationSync.refresh(
                recommendation: rec,
                modelContext: modelContext,
                force: true
            )
        }
    }

    private func currentNotificationTitle() -> String {
        let t = notificationTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? AquackCopy.defaultNotificationTitle : t
    }

    private func currentNotificationBody() -> String {
        let b = notificationBody.trimmingCharacters(in: .whitespacesAndNewlines)
        return b.isEmpty ? AquackCopy.defaultNotificationBody : b
    }

    private func handleNotificationToggle(_ enabled: Bool) {
        if enabled {
            Task {
                let granted = await NotificationManager.shared.requestAuthorization()
                await MainActor.run {
                    if granted {
                        notificationsEnabled = true
                        UserDefaults.standard.set(true, forKey: AppStorageKey.notificationsUserEnabled)
                        if notificationTitle.isEmpty { notificationTitle = AquackCopy.defaultNotificationTitle }
                        if notificationBody.isEmpty { notificationBody = AquackCopy.defaultNotificationBody }
                        saveNotificationMessage()
                        rescheduleNotification()
                    } else {
                        notificationsEnabled = false
                        UserDefaults.standard.set(false, forKey: AppStorageKey.notificationsUserEnabled)
                    }
                }
            }
        } else {
            NotificationManager.shared.cancelHydrationReminder()
            UserDefaults.standard.set(false, forKey: AppStorageKey.notificationsUserEnabled)
            notificationsEnabled = false
        }
    }

    private func rescheduleNotification() {
        let title = currentNotificationTitle()
        let body = currentNotificationBody()
        let mins = Int(selectedInterval.timeIntervalInSeconds / 60)
        if smartRemindersEnabled {
            let profile = HabitAnalyzer.analyze(
                context: modelContext,
                goalOz: rec.goalAmount.ozAmountInt
            )
            NotificationManager.shared.scheduleRepeatingOrSmart(
                smartEnabled: true,
                profile: profile,
                title: title,
                body: body,
                intervalMinutes: mins
            )
        } else {
            NotificationManager.shared.scheduleRepeatingOrSmart(
                smartEnabled: false,
                profile: nil,
                title: title,
                body: body,
                intervalMinutes: mins
            )
        }
        UserDefaults.standard.set(selectedInterval.rawValue, forKey: StorageKey.notificationsInterval)
    }

    @ViewBuilder
    private var stepsConnectionSection: some View {
        if healthEnabled {
            Toggle("Step count", isOn: $healthEnabled)
                .onChange(of: healthEnabled) { _, enabled in
                    guard !enabled else { return }
                    UserDefaults.standard.set(false, forKey: StorageKey.healthStepsEnabled)
                    Task {
                        await HydrationSync.refresh(
                            recommendation: rec,
                            modelContext: modelContext,
                            force: true
                        )
                    }
                }
        } else {
            Text("Connect Apple Health to include today's steps in your goal.")
                .hydrationFootnote()
            PrimaryWaterButton(title: "Connect step count") {
                healthAuthTrigger += 1
            }
        }
    }

    @MainActor
    private func finishSettingsHealthConnect() async {
        healthEnabled = true
        UserDefaults.standard.set(true, forKey: StorageKey.healthStepsEnabled)
        let steps = await HealthManager.shared.connectSteps()
        rec.lastStepsToday = steps
        await HydrationSync.refresh(
            recommendation: rec,
            modelContext: modelContext,
            force: true
        )
    }

}


