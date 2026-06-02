//
//  TutorialView.swift
//  Tutorial at the beginning: welcome, how it works, profile info (with default values), weather, directions, notifications, lets go
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

    var body: some View {
        HydrationPageShell(interactive: true, bubbleIntensity: 0.6) {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                howItWorksPage.tag(1)
                profileInfoPage.tag(2)
                weatherInfoPage.tag(3)
                stepsInfoPage.tag(4)
                notificationsInfoPage.tag(5)
                letsGoPage.tag(6)
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
            if page == 2 {
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
                    GlassInsetField(label: "Weight (lb)", text: $rec.weight)
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
            skipButton { currentPage = 3 }
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
                Text("Your location is only used to read the current temperature through Apple Weather—nothing is stored on our servers.")
                    .hydrationFootnote()
            }
            PrimaryWaterButton(title: "Enable local weather") {
                enableTutorialWeatherAndContinue()
            }
            skipButton {
                setLocationWeatherEnabled(false)
                currentPage = 4
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
                currentPage = 5
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
                currentPage = 6
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
                    Label("Settings tab — reminders & frequency", systemImage: "gearshape.fill")
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
                currentPage = 3
            }
        }
    }

    private func enableTutorialWeatherAndContinue() {
        setLocationWeatherEnabled(true)
        clearWeatherCache()
        currentPage = 4
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
        currentPage = 5
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
            }
            await MainActor.run { currentPage = 6 }
        }
    }
}
