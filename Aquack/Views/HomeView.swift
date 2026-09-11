//
//  HomeView.swift
//  Main UI. Hero header, progress ring, stats and data
//  Aquack
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var rec: Change
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(AppStorageKey.volumeUnit) private var volumeUnitRaw = VolumeUnit.ounces.rawValue
    @AppStorage(AppStorageKey.temperatureUnit) private var temperatureUnitRaw = TemperatureUnit.fahrenheit.rawValue
    @AppStorage(AppStorageKey.weightUnit) private var weightUnitRaw = WeightUnit.pounds.rawValue
    @AppStorage(AppStorageKey.openRetrospectiveLog) private var openRetrospectiveLog = false

    @State var intakeToday: Double = 0
    @State private var recentLogs: [HydrationLogEntry] = []
    @State private var showWater = false
    @State private var openWaterForRetrospective = false
    @State private var displayedProgress: Double = 0
    @State private var undoEntryPersistentID: PersistentIdentifier?
    @State private var showUndoBanner = false
    @State private var undoHideTask: Task<Void, Never>?

    private var volumeUnit: VolumeUnit { VolumeUnit(rawValue: volumeUnitRaw) ?? .ounces }
    private var temperatureUnit: TemperatureUnit { TemperatureUnit(rawValue: temperatureUnitRaw) ?? .fahrenheit }
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .pounds }
    var goalOz: Int { max(1, rec.goalAmount.ozAmountInt) }
    private var loggedOz: Int { Int(intakeToday.rounded()) }
    private var progress: Double { min(max(intakeToday / Double(goalOz), 0), 1) }
    private var remainingOz: Int { max(0, goalOz - loggedOz) }
    private var goalDisplay: Int { volumeUnit.displayAmount(fromOunces: Double(goalOz)) }
    private var loggedDisplay: Int { volumeUnit.displayAmount(fromOunces: Double(loggedOz)) }
    private var remainingDisplay: Int { volumeUnit.displayAmount(fromOunces: Double(remainingOz)) }
    private var weightDisplay: String {
        guard let pounds = Double(rec.weight), !rec.weight.isEmpty else {
            return rec.weight.isEmpty ? "—" : rec.weight
        }
        return weightUnit.displayString(fromPounds: pounds)
    }

    var body: some View {
        GeometryReader { viewport in
            ZStack {
                homeScroll(viewportHeight: HomeLayout.heroViewportHeight(in: viewport.size.height))

                if showUndoBanner {
                    VStack {
                        Spacer()
                        undoBanner
                            .padding(.horizontal, HomeLayout.horizontalPadding)
                            .padding(.bottom, HomeLayout.floatingTabBarInset + 12)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
                }

                if showWater {
                    WaterView(openForRetrospective: openWaterForRetrospective) {
                        refreshIntake()
                        presentUndoBanner()
                        Task {
                            await HydrationSync.refresh(recommendation: rec, modelContext: modelContext, force: true)
                        }
                    } onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            showWater = false
                            openWaterForRetrospective = false
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showWater)
        .animation(.easeInOut(duration: 0.25), value: showUndoBanner)
        .onAppear {
            refreshIntake()
            displayedProgress = progress
            handleRetrospectiveDeepLinkIfNeeded()
        }
        .onChange(of: openRetrospectiveLog) { _, shouldOpen in
            guard shouldOpen else { return }
            handleRetrospectiveDeepLinkIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshIntake()
            handleRetrospectiveDeepLinkIfNeeded()
            withAnimation(.easeInOut(duration: 0.75)) {
                displayedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            guard !showWater else { return }
            withAnimation(.easeInOut(duration: 0.75)) {
                displayedProgress = newValue
            }
        }
        .onChange(of: showWater) { _, isShowing in
            guard !isShowing else { return }
            refreshIntake()
            withAnimation(.easeInOut(duration: 0.75)) {
                displayedProgress = progress
            }
        }
    }

    private func homeScroll(viewportHeight: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    goalSection(scrollProxy: proxy, viewportHeight: viewportHeight)
                        .id("TOP")
                    detailsSection(proxy: proxy)
                        .id("DETAILS")
                }
            }
            .background(HomeScrollBackground())
        }
    }

    private func goalSection(scrollProxy: ScrollViewProxy, viewportHeight: CGFloat) -> some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                    AquackBrandHeader()
                        .padding(.top, max(geo.safeAreaInsets.top, HomeLayout.heroTopInset))

                    Spacer(minLength: 16)

                    heroProgressCluster

                    Spacer(minLength: 0)

                    VStack(spacing: 12) {
                        PrimaryWaterButton(title: "Log water", systemImage: "drop.fill") {
                            openWaterForRetrospective = false
                            withAnimation(.easeInOut(duration: 0.35)) {
                                showWater = true
                            }
                        }
                        .frame(maxWidth: HomeLayout.heroButtonMaxWidth)
                        .frame(maxWidth: .infinity)

                        OutlineWaterButton(title: "Log earlier", systemImage: "clock.arrow.circlepath") {
                            openWaterForRetrospective = true
                            withAnimation(.easeInOut(duration: 0.35)) {
                                showWater = true
                            }
                        }
                        .frame(maxWidth: HomeLayout.heroButtonMaxWidth)
                        .frame(maxWidth: .infinity)

                        HomeStatsTipsButton {
                            withAnimation(.easeInOut(duration: 0.45)) {
                                scrollProxy.scrollTo("DETAILS", anchor: .top)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                }
                .padding(.horizontal, HomeLayout.horizontalPadding)
                .padding(.bottom, max(geo.safeAreaInsets.bottom, HomeLayout.floatingTabBarInset))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(width: geo.size.width, height: viewportHeight)
        }
        .frame(height: viewportHeight)
    }

    private func detailsSection(proxy: ScrollViewProxy) -> some View {
        let healthConnected = UserDefaults.standard.bool(forKey: AppStorageKey.healthStepsEnabled)
        let weatherText = rec.lastWeatherTempF.map {
            "\(temperatureUnit.displayAmount(fromFahrenheit: $0))"
        } ?? "—"

        return VStack(alignment: .leading, spacing: HomeLayout.sectionSpacing) {
            OutlineWaterButton(title: "Back to goal", systemImage: "chevron.compact.up") {
                withAnimation(.easeInOut(duration: 0.45)) {
                    proxy.scrollTo("TOP", anchor: .top)
                }
            }
            .frame(maxWidth: 220)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)

            CapsuleSectionHeader(title: "Stats", systemImage: "chart.bar.fill")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: HomeLayout.cardSpacing), GridItem(.flexible(), spacing: HomeLayout.cardSpacing)],
                spacing: HomeLayout.cardSpacing
            ) {
                StatTile(
                    title: "Remaining",
                    value: "\(remainingDisplay)",
                    unit: volumeUnit.abbreviation,
                    icon: "drop.fill",
                    gradient: [HydrationTheme.accent, HydrationTheme.waterDeep]
                )
                StatTile(
                    title: "Weight",
                    value: weightDisplay,
                    unit: weightUnit.abbreviation,
                    icon: "person.fill",
                    gradient: [HydrationTheme.accentSoft, HydrationTheme.accent]
                )
                if healthConnected {
                    StatTile(
                        title: "Activity",
                        value: formattedCount(Int(rec.lastStepsToday)),
                        unit: "steps",
                        icon: "figure.walk",
                        gradient: [
                            Color(red: 0.45, green: 0.85, blue: 0.55),
                            Color(red: 0.25, green: 0.68, blue: 0.42)
                        ]
                    )
                } else {
                    StatPlaceholder(
                        title: "Activity",
                        hint: "Connect in Settings",
                        icon: "figure.walk"
                    )
                }
                if rec.lastWeatherTempF != nil {
                    StatTile(
                        title: "Weather",
                        value: weatherText,
                        unit: temperatureUnit.symbol,
                        icon: "thermometer.medium",
                        gradient: [Color.orange, HydrationTheme.accent]
                    )
                } else {
                    StatPlaceholder(
                        title: "Weather",
                        hint: "Enable in Settings",
                        icon: "cloud.sun"
                    )
                }
            }

            if isShowingLiveWeatherKitData() {
                WeatherAttributionView()
            }

            CapsuleSectionHeader(title: "Recent", systemImage: "clock")

            GlassCard {
                if recentLogs.isEmpty {
                    Text("No drinks logged yet today. Tap Log water to start.")
                        .hydrationFootnote()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(recentLogs.enumerated()), id: \.element.persistentModelID) { index, entry in
                            if index > 0 { Divider().padding(.vertical, 8) }
                            recentRow(entry)
                        }
                    }
                }
            }

            CapsuleSectionHeader(title: "Tips", systemImage: "lightbulb.fill")

            GlassCard {
                VStack(spacing: HomeLayout.cardSpacing) {
                    AquackCharacterImage(size: 48)
                    Text(hydrationTip)
                        .font(HydrationTypography.bodyEmphasis)
                        .foregroundStyle(HydrationTheme.title)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }

            GlassCard {
                VStack(alignment: .center, spacing: 8) {
                    Text("Why it matters")
                        .multilineTextAlignment(.center)
                        .font(HydrationTypography.bodyEmphasis)
                        .foregroundStyle(HydrationTheme.title)
                    Text("Small sips through the day beat one big chug. Reminders in Settings help you stay steady.")
                        .font(HydrationTypography.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(HydrationTheme.label)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            CapsuleSectionHeader(title: "Benefits", systemImage: "sparkles")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HomeLayout.cardSpacing) {
                    BenefitCard(icon: "brain.head.profile", title: "Focus", desc: "Hydration boosts concentration.", color: .purple)
                    BenefitCard(icon: "bolt.fill", title: "Energy", desc: "Reduces fatigue.", color: .orange)
                    BenefitCard(icon: "leaf.fill", title: "Skin", desc: "Improves elasticity.", color: .green)
                }
                .padding(.horizontal, 1)
            }
            .padding(.horizontal, -1)

            GlassCard {
                HStack(spacing: HomeLayout.cardSpacing) {
                    GradientIconBadge(
                        systemName: "figure.run.circle.fill",
                        colors: [HydrationTheme.accent, HydrationTheme.waterDeep],
                        size: 32
                    )
                    Text(rec.activityLevel.displayLabel)
                        .font(HydrationTypography.body)
                        .foregroundStyle(HydrationTheme.title)
                    Spacer(minLength: 0)
                }
            }

        }
        .padding(.horizontal, HomeLayout.horizontalPadding)
        .padding(.top, 12)
    }

    private var heroProgressCluster: some View {
        VStack(spacing: 10) {
            progressRing
            goalLoggedCard
        }
        .frame(maxWidth: .infinity)
    }

    private var progressRing: some View {
        let ringSize = HomeLayout.heroProgressRingSize
        let stroke = HomeLayout.heroProgressRingStroke

        return ZStack {
            Circle()
                .stroke(HydrationTheme.accentSoft.opacity(0.65), lineWidth: stroke)
            if progress > 0 {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        HydrationTheme.accent,
                        style: StrokeStyle(lineWidth: stroke, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(HydrationTypography.heroPercent)
                    .foregroundStyle(HydrationTheme.accent)
                Text("today")
                    .font(HydrationTypography.footnote)
                    .foregroundStyle(HydrationTheme.label)
            }
        }
        .frame(width: ringSize, height: ringSize)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 10)
    }

    private var goalLoggedCard: some View {
        HStack(spacing: 0) {
            statColumn(label: "Goal", amount: goalDisplay)
            Circle()
                .fill(HydrationTheme.accentSoft)
                .frame(width: 4, height: 4)
                .padding(.horizontal, 10)
            statColumn(label: "Logged", amount: loggedDisplay)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 18)
        .frame(maxWidth: HomeLayout.heroGoalCardMaxWidth)
        .glassSurface(cornerRadius: 20)
    }

    private func statColumn(label: String, amount: Int) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(HydrationTypography.footnote)
                .foregroundStyle(HydrationTheme.label)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(amount)")
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(HydrationTheme.title)
                Text(volumeUnit.abbreviation)
                    .font(HydrationTypography.footnote)
                    .foregroundStyle(HydrationTheme.title)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var hydrationTip: String {
        let unit = volumeUnit.abbreviation
        if remainingOz == 0 {
            return "You hit your goal today—nice work! Keep sipping to stay steady."
        }
        let sipOz = min(16, max(8, remainingOz / 4))
        let sipDisplay = volumeUnit.displayAmount(fromOunces: Double(sipOz))
        return "You're \(remainingDisplay) \(unit) from your goal. Try \(sipDisplay) \(unit) in the next hour!"
    }

    private func refreshIntake() {
        intakeToday = HydrationHistoryStore.todayIntakeOz(context: modelContext)
        recentLogs = HydrationHistoryStore.recentEntries(limit: 3, context: modelContext)
        rec.dailyIntake = "\(loggedOz)"
        WidgetSnapshotSync.publish(goalOz: goalOz, intakeOz: intakeToday)
    }

    private func recentRow(_ entry: HydrationLogEntry) -> some View {
        HStack(spacing: 12) {
            GradientIconBadge(
                systemName: "drop.fill",
                colors: [HydrationTheme.accent, HydrationTheme.waterDeep],
                size: 28
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(recentTitle(for: entry))
                    .font(HydrationTypography.bodyEmphasis)
                    .foregroundStyle(HydrationTheme.title)
                Text(relativeTime(from: entry.timestamp))
                    .font(HydrationTypography.footnote)
                    .foregroundStyle(HydrationTheme.label)
            }
            Spacer(minLength: 8)
            Text("\(volumeUnit.displayAmount(fromOunces: entry.ounces)) \(volumeUnit.abbreviation)")
                .font(HydrationTypography.bodyEmphasis)
                .foregroundStyle(HydrationTheme.accent)
            Button {
                undo(entry)
            } label: {
                Text("Undo")
                    .font(HydrationTypography.footnoteEmphasis)
                    .foregroundStyle(HydrationTheme.label)
            }
            .buttonStyle(.plain)
        }
    }

    private func recentTitle(for entry: HydrationLogEntry) -> String {
        if let note = entry.note, !note.isEmpty { return note }
        switch entry.source {
        case "retrospective": return "Earlier drink"
        case "legacy": return "Imported"
        default: return "Water"
        }
    }

    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var undoBanner: some View {
        HStack(spacing: 12) {
            Text("Drink logged")
                .font(HydrationTypography.bodyEmphasis)
                .foregroundStyle(HydrationTheme.title)
            Spacer()
            Button("Undo") {
                if let id = undoEntryPersistentID,
                   let entry = recentLogs.first(where: { $0.persistentModelID == id }) {
                    undo(entry)
                } else {
                    _ = HydrationHistoryStore.deleteLatest(context: modelContext)
                    refreshIntake()
                    dismissUndoBanner()
                }
            }
            .font(HydrationTypography.bodyEmphasis)
            .foregroundStyle(HydrationTheme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassSurface(cornerRadius: 18)
    }

    private func presentUndoBanner() {
        recentLogs = HydrationHistoryStore.recentEntries(limit: 3, context: modelContext)
        undoEntryPersistentID = recentLogs.first?.persistentModelID
        showUndoBanner = true
        undoHideTask?.cancel()
        undoHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            dismissUndoBanner()
        }
    }

    private func dismissUndoBanner() {
        showUndoBanner = false
        undoEntryPersistentID = nil
        undoHideTask?.cancel()
        undoHideTask = nil
    }

    private func undo(_ entry: HydrationLogEntry) {
        HydrationHistoryStore.delete(entry, context: modelContext)
        refreshIntake()
        dismissUndoBanner()
        withAnimation(.easeInOut(duration: 0.75)) {
            displayedProgress = progress
        }
    }

    private func handleRetrospectiveDeepLinkIfNeeded() {
        guard openRetrospectiveLog else { return }
        openRetrospectiveLog = false
        openWaterForRetrospective = true
        withAnimation(.easeInOut(duration: 0.35)) {
            showWater = true
        }
    }

    private func formattedCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Home stats tiles

private enum HomeTileMetrics {
    static let minHeight: CGFloat = 118
    static let iconSize: CGFloat = 36
    static let cornerRadius: CGFloat = 24
    static let inset: CGFloat = 16
}

struct StatTile: View {
    var title: String
    var value: String
    var unit: String
    var icon: String
    var gradient: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GradientIconBadge(
                systemName: icon,
                colors: gradient,
                size: HomeTileMetrics.iconSize
            )

            Spacer(minLength: 14)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(HydrationTypography.metricLarge)
                    .foregroundStyle(HydrationTheme.title)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(HydrationTypography.footnote)
                        .foregroundStyle(HydrationTheme.title)
                }
            }

            Spacer(minLength: 6)

            Text(title.uppercased())
                .font(HydrationTypography.footnoteEmphasis)
                .foregroundStyle(HydrationTheme.label)
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity, minHeight: HomeTileMetrics.minHeight, alignment: .topLeading)
        .padding(HomeTileMetrics.inset)
        .glassSurface(cornerRadius: HomeTileMetrics.cornerRadius)
    }
}

struct StatPlaceholder: View {
    var title: String
    var hint: String
    var icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GradientIconBadge(
                systemName: icon,
                colors: [HydrationTheme.iconGrayTop, HydrationTheme.iconGrayBottom],
                size: HomeTileMetrics.iconSize
            )

            Spacer(minLength: 14)

            Text(hint)
                .font(HydrationTypography.bodyEmphasis)
                .foregroundStyle(HydrationTheme.title)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 6)

            Text(title.uppercased())
                .font(HydrationTypography.footnoteEmphasis)
                .foregroundStyle(HydrationTheme.label)
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity, minHeight: HomeTileMetrics.minHeight, alignment: .topLeading)
        .padding(HomeTileMetrics.inset)
        .glassSurface(cornerRadius: HomeTileMetrics.cornerRadius)
    }
}

struct BenefitCard: View {
    var icon: String
    var title: String
    var desc: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(HydrationTypography.bodyEmphasis)
                .foregroundStyle(color)
            Text(title)
                .font(HydrationTypography.bodyEmphasis)
                .foregroundStyle(HydrationTheme.title)
            Text(desc)
                .font(HydrationTypography.footnote)
                .foregroundStyle(HydrationTheme.label)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(HomeLayout.cardSpacing + 4)
        .frame(width: 128, alignment: .topLeading)
        .glassSurface(cornerRadius: 18)
    }
}
