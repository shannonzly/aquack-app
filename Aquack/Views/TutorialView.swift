//
//  TutorialView.swift
//  Tutorial at the beginning: welcome, how it works, units, reset time, profile, weather, steps, notifications, lets go
//  Aquack
//

import SwiftUI
import SwiftData

private enum TutorialStorageKey {
    static let notificationsInterval = "notificationsInterval"
}

struct TutorialView: View {
    @Binding var didFinishTutorial: Bool
    @EnvironmentObject var rec: Change
    @Environment(\.modelContext) private var modelContext
    @State private var currentPage = 0
    @State private var selectedInterval: SettingsInfo.Interval = .one
    @State private var isUpdatingProfile = false
    @State private var healthAuthTrigger = 0
    @AppStorage(AppStorageKey.volumeUnit) private var volumeUnitRaw = VolumeUnit.ounces.rawValue
    @AppStorage(AppStorageKey.temperatureUnit) private var temperatureUnitRaw = TemperatureUnit.fahrenheit.rawValue
    @AppStorage(AppStorageKey.weightUnit) private var weightUnitRaw = WeightUnit.pounds.rawValue
    @AppStorage(AppStorageKey.dailyResetMinutes) private var dailyResetMinutes = 0

    private var selectedVolumeUnit: Binding<VolumeUnit> {
        Binding(
            get: { VolumeUnit(rawValue: volumeUnitRaw) ?? .ounces },
            set: { volumeUnitRaw = $0.rawValue }
        )
    }

    private var selectedTemperatureUnit: Binding<TemperatureUnit> {
        Binding(
            get: { TemperatureUnit(rawValue: temperatureUnitRaw) ?? .fahrenheit },
            set: { temperatureUnitRaw = $0.rawValue }
        )
    }

    private var selectedWeightUnit: Binding<WeightUnit> {
        Binding(
            get: { WeightUnit(rawValue: weightUnitRaw) ?? .pounds },
            set: { weightUnitRaw = $0.rawValue }
        )
    }

    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .pounds }

    private var weightField: Binding<String> {
        WeightUnit.displayBinding(storedPounds: $rec.weight)
    }

    private var resetTime: Binding<Date> {
        DailyResetPreference.dateBinding(minutes: $dailyResetMinutes)
    }

    var body: some View {
        HydrationPageShell(interactive: true, bubbleIntensity: 0.6) {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                howItWorksPage.tag(1)
                unitsPage.tag(2)
                resetTimePage.tag(3)
                profileInfoPage.tag(4)
                weatherInfoPage.tag(5)
                stepsInfoPage.tag(6)
                notificationsInfoPage.tag(7)
                letsGoPage.tag(8)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
        .healthKitAccessOnTrigger($healthAuthTrigger) {
            Task { await finishTutorialHealthConnect() }
        }
        .onAppear {
            ProfileDefaults.applyIfEmpty(to: rec)
            if let raw = UserDefaults.standard.string(forKey: TutorialStorageKey.notificationsInterval),
               let interval = SettingsInfo.Interval(rawValue: raw) {
                selectedInterval = interval
            }
        }
        .onChange(of: currentPage) { _, page in
            if page == 4 {
                ProfileDefaults.applyIfEmpty(to: rec)
            }
        }
    }

    private var welcomePage: some View {
        tutorialPage {
            PageHeroHeader(
                title: "Welcome!",
                subtitle: "Your personal hydration companion",
                useCharacter: true
            )
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Track drinks, hit your goal, and get tips from Aquack.")
                        .hydrationFootnote()
                    Text("Let's set up your profile, permissions, and reminders in a few quick steps.")
                        .hydrationBodyText()
                }
            }
            PrimaryWaterButton(title: "Get Started") {
                withAnimation { currentPage = 1 }
            }
        }
    }

    private var howItWorksPage: some View {
        tutorialPage {
            PageHeroHeader(
                title: "How it works",
                subtitle: "Goals, logging, and rising water",
                systemImage: "drop.fill"
            )
            GlassCard {
                Text("Set your daily goal, log water throughout the day, and watch your progress fill the screen.")
                    .hydrationFootnote()
            }
            PrimaryWaterButton(title: "Next") { currentPage = 2 }
        }
    }

    private var unitsPage: some View {
        tutorialPage {
            PageHeroHeader(
                title: "Units",
                subtitle: "Water, weight, and temperature",
                systemImage: "ruler"
            )
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Goals, weight, and weather will use these units. Change them anytime in Settings.")
                        .hydrationFootnote()

                    Text("Volume")
                        .font(HydrationTypography.bodyEmphasis)
                        .foregroundStyle(HydrationTheme.title)
                    Picker("Volume unit", selection: selectedVolumeUnit) {
                        ForEach(VolumeUnit.allCases) { unit in
                            Text(unit.abbreviation.uppercased()).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    Divider()

                    Text("Weight")
                        .font(HydrationTypography.bodyEmphasis)
                        .foregroundStyle(HydrationTheme.title)
                    Picker("Weight unit", selection: selectedWeightUnit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.abbreviation).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    Divider()

                    Text("Temperature")
                        .font(HydrationTypography.bodyEmphasis)
                        .foregroundStyle(HydrationTheme.title)
                    Picker("Temperature unit", selection: selectedTemperatureUnit) {
                        ForEach(TemperatureUnit.allCases) { unit in
                            Text(unit.symbol).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            PrimaryWaterButton(title: "Continue") { currentPage = 3 }
        }
    }

    private var resetTimePage: some View {
        tutorialPage {
            PageHeroHeader(
                title: "Daily reset",
                subtitle: "When your water count starts over",
                systemImage: "clock.arrow.circlepath"
            )
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose when “today” resets—midnight by default, or later if you stay up past midnight.")
                        .hydrationFootnote()

                    DatePicker(
                        "Reset time",
                        selection: resetTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Change this anytime in Settings → Preferences.")
                        .hydrationFootnote()
                }
            }
            PrimaryWaterButton(title: "Continue") { currentPage = 4 }
            skipButton {
                dailyResetMinutes = 0
                currentPage = 4
            }
        }
    }

    private var profileInfoPage: some View {
        tutorialPage {
            PageHeroHeader(
                title: "Your profile",
                subtitle: "Personalize your daily goal",
                systemImage: "person.fill"
            )
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("We use this to calculate how much water you need. You can edit it anytime in the Profile tab.")
                        .hydrationFootnote()

                    GlassInsetField(label: "Height (cm)", text: $rec.height)
                    GlassInsetField(label: "Weight (\(weightUnit.abbreviation))", text: weightField)
                    GlassInsetField(label: "Age", text: $rec.age, keyboard: .numberPad)
                    if let ageInt = Int(rec.age), !rec.age.isEmpty, ageInt < 15 {
                        Text("Age must be 15 or older")
                            .font(HydrationTypography.footnote)
                            .foregroundStyle(.red)
                    }

                    Divider()

                    ProfileMenuPicker(title: "Gender", selection: $rec.gender) {
                        ForEach(UserInfo.Gender.allCases) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                    ProfileMenuPicker(title: "Activity", selection: $rec.activityLevel) {
                        ForEach(UserInfo.ActivityLevel.allCases) { a in
                            Text(a.displayLabel).tag(a)
                        }
                    }
                    ProfileMenuPicker(title: "Climate", selection: $rec.climate) {
                        ForEach(UserInfo.Climate.allCases) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                }
            }
            PrimaryWaterButton(title: isUpdatingProfile ? "Saving…" : "Save & continue", disabled: isUpdatingProfile) {
                saveProfileAndContinue()
            }
            skipButton { currentPage = 5 }
        }
    }

    private var weatherInfoPage: some View {
        tutorialPage {
            PageHeroHeader(
                title: "Local weather",
                subtitle: "Goals that adapt to the day",
                systemImage: "cloud.sun.fill"
            )
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your location is only used to read the current temperature through Apple Weather—nothing is stored on our servers.")
                        .hydrationFootnote()
                    WeatherAttributionView()
                }
            }
            PrimaryWaterButton(title: "Enable local weather") {
                enableTutorialWeatherAndContinue()
            }
            skipButton {
                setLocationWeatherEnabled(false)
                currentPage = 6
            }
        }
    }

    private var stepsInfoPage: some View {
        tutorialPage {
            PageHeroHeader(
                title: "Step count",
                subtitle: "Bonus hydration when you're active",
                systemImage: "figure.walk"
            )
            GlassCard {
                Text("Steps are read from your phone's activity data and stay on your device.")
                    .hydrationFootnote()
            }
            PrimaryWaterButton(title: "Connect step count") {
                healthAuthTrigger += 1
            }
            skipButton {
                UserDefaults.standard.set(false, forKey: AppStorageKey.healthStepsEnabled)
                currentPage = 7
            }
        }
    }

    private var notificationsInfoPage: some View {
        tutorialPage {
            PageHeroHeader(
                title: "Reminders",
                subtitle: "Gentle nudges from Aquack",
                systemImage: "bell.fill"
            )
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Stay on track with your daily goal and avoid long stretches without drinking water.")
                        .hydrationFootnote()

                    Picker("Reminder frequency", selection: $selectedInterval) {
                        ForEach(SettingsInfo.Interval.allCases) { interval in
                            Text(interval.rawValue).tag(interval)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Change reminders anytime in Settings → Reminders.")
                        .hydrationFootnote()
                }
            }
            PrimaryWaterButton(title: "Enable reminders") {
                enableRemindersAndContinue()
            }
            skipButton {
                saveNotificationInterval()
                currentPage = 8
            }
        }
    }

    private var letsGoPage: some View {
        tutorialPage {
            PageHeroHeader(
                title: "You're all set!",
                subtitle: "Profile & reminders live in their tabs",
                systemImage: "drop.fill"
            )
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Profile tab — body info & daily goal", systemImage: "person.fill")
                    Label("Settings tab — units, reset time & reminders", systemImage: "gearshape.fill")
                }
                .font(HydrationTypography.body)
                .foregroundStyle(HydrationTheme.label)
            }
            PrimaryWaterButton(title: "Stay hydrated!") {
                didFinishTutorial = true
            }
        }
    }

    private func tutorialPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        KeyboardDismissingScrollView {
            VStack(alignment: .leading, spacing: HomeLayout.sectionSpacing) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, HomeLayout.horizontalPadding)
            .padding(.vertical, HomeLayout.sectionSpacing)
        }
    }

    private func skipButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Skip for now")
                .font(HydrationTypography.body)
                .foregroundStyle(HydrationTheme.label)
        }
        .buttonStyle(.plain)
    }

    private func saveProfileAndContinue() {
        isUpdatingProfile = true
        rec.usingRec = true
        rec.goalAmount = rec.recommendedAmount
        Task {
            await HydrationSync.refresh(
                recommendation: rec,
                modelContext: modelContext,
                force: true
            )
            await MainActor.run {
                isUpdatingProfile = false
                currentPage = 5
            }
        }
    }

    private func enableTutorialWeatherAndContinue() {
        setLocationWeatherEnabled(true)
        clearWeatherCache()
        LocationManager.shared.requestAuthorization()
        currentPage = 6
        Task {
            await HydrationSync.refresh(
                recommendation: rec,
                modelContext: modelContext,
                force: true
            )
        }
    }

    @MainActor
    private func finishTutorialHealthConnect() async {
        UserDefaults.standard.set(true, forKey: AppStorageKey.healthStepsEnabled)
        let steps = await HealthManager.shared.connectSteps()
        rec.lastStepsToday = steps
        currentPage = 7
        await HydrationSync.refresh(
            recommendation: rec,
            modelContext: modelContext,
            force: true
        )
    }

    private func saveNotificationInterval() {
        UserDefaults.standard.set(selectedInterval.rawValue, forKey: TutorialStorageKey.notificationsInterval)
    }

    private func enableRemindersAndContinue() {
        saveNotificationInterval()
        let intervalMinutes = Int(selectedInterval.timeIntervalInSeconds / 60)
        Task {
            let granted = await NotificationManager.shared.requestAuthorization()
            UserDefaults.standard.set(granted, forKey: AppStorageKey.notificationsUserEnabled)
            if granted {
                NotificationManager.shared.scheduleRepeatingNotification(
                    title: AquackCopy.defaultNotificationTitle,
                    body: AquackCopy.defaultNotificationBody,
                    intervalMinutes: intervalMinutes
                )
                NotificationManager.shared.refreshForgotToLogReminder()
            }
            await MainActor.run { currentPage = 8 }
        }
    }
}
