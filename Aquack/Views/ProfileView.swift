//
//  ProfileView.swift
//  Info that user puts in and used to calculate recommended value on rule based
//  Aquack
//

import SwiftData
import SwiftUI

private enum ProfileStorageKey {
    static let lastBreakdown = AppStorageKey.lastBreakdown
    static let lastBreakdownUsedSteps = AppStorageKey.lastBreakdownUsedSteps
    static let lastBreakdownUsedWeather = AppStorageKey.lastBreakdownUsedWeather
}

struct ProfileView: View {
    @EnvironmentObject var rec: Change
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKey.volumeUnit) private var volumeUnitRaw = VolumeUnit.ounces.rawValue
    @AppStorage(AppStorageKey.temperatureUnit) private var temperatureUnitRaw = TemperatureUnit.fahrenheit.rawValue
    @AppStorage(AppStorageKey.weightUnit) private var weightUnitRaw = WeightUnit.pounds.rawValue

    @State private var dailyGoal: SettingsInfo.Goal = .rec
    @State private var customGoal = ""
    @State private var hydrationBreakdown: HydrationBreakdown?
    @State private var usedStepsData = false
    @State private var usedLiveWeather = false
    @State private var isUpdating = false

    private var volumeUnit: VolumeUnit { VolumeUnit(rawValue: volumeUnitRaw) ?? .ounces }
    private var temperatureUnit: TemperatureUnit { TemperatureUnit(rawValue: temperatureUnitRaw) ?? .fahrenheit }
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .pounds }

    private var weightField: Binding<String> {
        WeightUnit.displayBinding(storedPounds: $rec.weight)
    }

    var body: some View {
        HydrationPageShell(bubbleIntensity: 0.55) {
            KeyboardDismissingScrollView {
                VStack(alignment: .leading, spacing: HomeLayout.sectionSpacing) {
                    PageHeroHeader(
                        title: "Goals",
                        subtitle: "Tune your body profile and daily target",
                        systemImage: "target"
                    )

                    profileSection(title: "Your body", systemImage: "person.fill") {
                        GlassInsetField(label: "Height (cm)", text: $rec.height)
                        GlassInsetField(label: "Weight (\(weightUnit.abbreviation))", text: weightField)
                        GlassInsetField(label: "Age", text: $rec.age, keyboard: .numberPad)
                    }

                    profileSection(title: "Profile", systemImage: "slider.horizontal.3") {
                        ProfileMenuPicker(title: "Gender", selection: $rec.gender) {
                            ForEach(UserInfo.Gender.allCases) { gender in
                                Text(gender.rawValue).tag(gender)
                            }
                        }
                        ProfileMenuPicker(title: "Activity Level", selection: $rec.activityLevel) {
                            ForEach(UserInfo.ActivityLevel.allCases) { level in
                                Text(level.displayLabel).tag(level)
                            }
                        }
                        ProfileMenuPicker(title: "Climate", selection: $rec.climate) {
                            ForEach(UserInfo.Climate.allCases) { climate in
                                Text(climate.rawValue).tag(climate)
                            }
                        }
                    }

                    recommendedHero

                    PrimaryWaterButton(
                        title: isUpdating ? "Updating…" : "Update recommendation",
                        disabled: isUpdating
                    ) {
                        submitUpdate()
                    }

                    profileSection(title: "Daily goal", systemImage: "flag.fill") {
                        VStack(spacing: HomeLayout.cardSpacing + 4) {
                            ProfileMenuPicker(title: "Goal type", selection: $dailyGoal) {
                                ForEach(SettingsInfo.Goal.allCases) { goal in
                                    Text(goal.rawValue).tag(goal)
                                }
                            }

                            if dailyGoal == .custom {
                                GlassInsetField(
                                    label: "Custom amount (\(volumeUnit.abbreviation))",
                                    text: $customGoal,
                                    keyboard: .numberPad
                                )
                            }

                            PrimaryWaterButton(title: "Save goal") {
                                saveGoal()
                            }
                        }
                    }

                    whyThisAmountSection
                }
                .hydrationPageContent()
            }
        }
        .onAppear {
            loadGoalSelection()
            loadSavedBreakdown()
        }
        .onChange(of: rec.usingRec) { _, _ in
            loadGoalSelection()
        }
        .onChange(of: rec.goalAmount) { _, _ in
            if rec.usingRec { refreshCustomGoalDisplay() }
        }
        .onChange(of: volumeUnitRaw) { _, _ in
            refreshCustomGoalDisplay()
        }
    }

    // MARK: - Recommended hero

    private var recommendedHero: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(displayRecommendedAmount)
                    .font(HydrationTypography.metricLarge)
                    .foregroundStyle(HydrationTheme.accent)
                Text(volumeUnit.abbreviation)
                    .font(HydrationTypography.bodyEmphasis)
                    .foregroundStyle(HydrationTheme.label)
            }
            Text("recommended today")
                .font(HydrationTypography.footnote)
                .foregroundStyle(HydrationTheme.label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HomeLayout.cardSpacing)
    }

    private var displayRecommendedAmount: String {
        let oz: Double
        if let breakdown = hydrationBreakdown {
            oz = Double(breakdown.totalOz)
        } else {
            oz = Double(rec.recommendedAmount.ozAmountInt)
        }
        return volumeUnit.displayString(fromOunces: oz)
    }

    // MARK: - Why this amount

    @ViewBuilder
    private var whyThisAmountSection: some View {
        VStack(alignment: .leading, spacing: HomeLayout.cardSpacing) {
            CapsuleSectionHeader(title: "Why this amount", systemImage: "questionmark.circle.fill")

            if let breakdown = hydrationBreakdown {
                GlassCard {
                    VStack(alignment: .leading, spacing: HomeLayout.cardSpacing + 4) {
                        Text("Data used")
                            .font(HydrationTypography.bodyEmphasis)
                            .foregroundStyle(HydrationTheme.title)

                        HStack(spacing: HomeLayout.sectionSpacing) {
                            if usedStepsData {
                                dataChip(icon: "figure.walk", text: "\(formattedSteps) steps")
                            }
                            if let temp = rec.lastWeatherTempF {
                                dataChip(
                                    icon: "thermometer.medium",
                                    text: "\(temperatureUnit.displayString(fromFahrenheit: temp))\(usedLiveWeather ? "" : " (est.)")"
                                )
                            }
                        }

                        Text(profileSummary)
                            .font(HydrationTypography.footnote)
                            .foregroundStyle(HydrationTheme.label)
                            .fixedSize(horizontal: false, vertical: true)

                        if usedLiveWeather {
                            WeatherAttributionView()
                                .padding(.top, 4)
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: HomeLayout.cardSpacing) {
                        Text("Calculation")
                            .font(HydrationTypography.bodyEmphasis)
                            .foregroundStyle(HydrationTheme.title)

                        breakdownRow("Base (weight × gender)", breakdown.baseOz)
                        breakdownRow("Activity level", breakdown.activityOz)
                        breakdownRow(
                            "Step bonus (~\(volumeUnit.displayAmount(fromOunces: 12)) \(volumeUnit.abbreviation) per 10k steps)",
                            breakdown.stepsOz
                        )
                        breakdownRow("Temperature bonus", breakdown.heatOz)
                        if breakdown.habitOz != 0 {
                            breakdownRow("Learned from your history", breakdown.habitOz)
                        }

                        Divider()

                        breakdownRow("Rule-based total", breakdown.ruleTotalOz)
                        breakdownRow("Total recommended", breakdown.totalOz)
                    }
                }
            } else {
                GlassCard {
                    Text("Tap “Update recommendation” above to see how your goal is calculated from your profile and, if enabled in Settings, steps and weather.")
                        .font(HydrationTypography.footnote)
                        .foregroundStyle(HydrationTheme.label)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dataChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(HydrationTypography.footnoteEmphasis)
                .foregroundStyle(HydrationTheme.accent)
            Text(text)
                .font(HydrationTypography.body)
                .foregroundStyle(HydrationTheme.title)
        }
    }

    private var formattedSteps: String {
        let steps = Int(rec.lastStepsToday)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    private var profileSummary: String {
        let weight: String
        if rec.weight.isEmpty {
            weight = "—"
        } else if let pounds = Double(rec.weight) {
            weight = "\(weightUnit.displayString(fromPounds: pounds)) \(weightUnit.abbreviation)"
        } else {
            weight = "\(rec.weight) \(weightUnit.abbreviation)"
        }
        let activity = rec.activityLevel.displayLabel
        return "Profile: \(weight), \(rec.gender.rawValue), \(activity), \(rec.climate.rawValue)"
    }

    private func breakdownRow(_ label: String, _ oz: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(HydrationTypography.body)
                .foregroundStyle(HydrationTheme.title)
            Spacer(minLength: 12)
            Text("\(volumeUnit.displayAmount(fromOunces: Double(oz))) \(volumeUnit.abbreviation)")
                .font(HydrationTypography.bodyEmphasis)
                .foregroundStyle(HydrationTheme.accent)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func profileSection<Content: View>(
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

    private func loadGoalSelection() {
        dailyGoal = rec.usingRec ? .rec : .custom
        refreshCustomGoalDisplay()
    }

    private func refreshCustomGoalDisplay() {
        let oz = Double(max(1, rec.goalAmount.ozAmountInt))
        customGoal = volumeUnit.displayString(fromOunces: oz)
    }

    private func loadSavedBreakdown() {
        guard let data = UserDefaults.standard.data(forKey: ProfileStorageKey.lastBreakdown),
              let decoded = try? JSONDecoder().decode(HydrationBreakdown.self, from: data) else { return }
        hydrationBreakdown = decoded
        usedStepsData = UserDefaults.standard.bool(forKey: ProfileStorageKey.lastBreakdownUsedSteps)
        usedLiveWeather = UserDefaults.standard.bool(forKey: ProfileStorageKey.lastBreakdownUsedWeather)
    }

    private func saveGoal() {
        if dailyGoal == .rec {
            rec.usingRec = true
            rec.goalAmount = rec.recommendedAmount.normalizedOzString
        } else {
            rec.usingRec = false
            let entered = Double(customGoal.filter { $0.isNumber || $0 == "." }) ?? 0
            let oz = max(1, Int(volumeUnit.toOunces(entered).rounded()))
            rec.goalAmount = "\(oz)"
        }
    }

    private func submitUpdate() {
        isUpdating = true
        Task {
            await HydrationSync.refresh(recommendation: rec, modelContext: modelContext, force: true)
            await MainActor.run {
                loadSavedBreakdown()
                if rec.usingRec {
                    rec.goalAmount = rec.recommendedAmount.normalizedOzString
                }
                isUpdating = false
            }
        }
    }
}
