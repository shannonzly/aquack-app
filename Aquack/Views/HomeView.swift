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

    @State private var intakeToday: Double = 0
    @State private var showWater = false
    @State private var displayedProgress: Double = 0

    private var goalOz: Int { max(1, rec.goalAmount.ozAmountInt) }
    private var loggedOz: Int { Int(intakeToday.rounded()) }
    private var progress: Double { min(max(intakeToday / Double(goalOz), 0), 1) }
    private var remainingOz: Int { max(0, goalOz - loggedOz) }

    var body: some View {
        GeometryReader { viewport in
            ZStack {
                homeScroll(viewportHeight: HomeLayout.heroViewportHeight(in: viewport.size.height))

                if showWater {
                    WaterView {
                        refreshIntake()
                        Task {
                            await HydrationSync.refresh(recommendation: rec, modelContext: modelContext, force: true)
                        }
                    } onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            showWater = false
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showWater)
        .onAppear {
            refreshIntake()
            displayedProgress = progress
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
        let weatherText = rec.lastWeatherTempF.map { "\(Int($0))" } ?? "—"

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
                    value: "\(remainingOz)",
                    unit: "oz",
                    icon: "drop.fill",
                    gradient: [HydrationTheme.accent, HydrationTheme.waterDeep]
                )
                StatTile(
                    title: "Weight",
                    value: rec.weight.isEmpty ? "—" : rec.weight,
                    unit: "lb",
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
                        unit: "°F",
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
            statColumn(label: "Goal", amount: goalOz)
            Circle()
                .fill(HydrationTheme.accentSoft)
                .frame(width: 4, height: 4)
                .padding(.horizontal, 10)
            statColumn(label: "Logged", amount: loggedOz)
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
                Text("oz")
                    .font(HydrationTypography.footnote)
                    .foregroundStyle(HydrationTheme.title)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var hydrationTip: String {
        if remainingOz == 0 {
            return "You hit your goal today—nice work! Keep sipping to stay steady."
        }
        let sip = min(16, max(8, remainingOz / 4))
        return "You're \(remainingOz) oz from your goal. Try \(sip) oz in the next hour!"
    }

    private func refreshIntake() {
        intakeToday = HydrationHistoryStore.todayIntakeOz(context: modelContext)
        rec.dailyIntake = "\(loggedOz)"
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
