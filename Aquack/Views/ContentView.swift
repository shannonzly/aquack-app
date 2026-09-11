//
//  ContentView.swift
//  Aquack
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @AppStorage(AppStorageKey.duckCoachEnabled) private var duckCoachEnabled = true
    @AppStorage(AppStorageKey.openRetrospectiveLog) private var openRetrospectiveLog = false
    @AppStorage(AppStorageKey.themeRevision) private var themeRevision = 0

    var body: some View {
        ZStack {
            AmbientPageBackground(bubbleIntensity: 0.35)
                .ignoresSafeArea()

            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Observe theme changes so accent colors refresh across tabs.
        .animation(nil, value: themeRevision)
        .tint(HydrationTheme.accent)
        .safeAreaInset(edge: .bottom, spacing: 8) {
            GlassTabBar(selection: $selectedTab, showCoach: duckCoachEnabled)
        }
        .onChange(of: duckCoachEnabled) { _, enabled in
            if !enabled, selectedTab == .coach {
                selectedTab = .home
            }
        }
        .onChange(of: openRetrospectiveLog) { _, shouldOpen in
            if shouldOpen {
                selectedTab = .home
            }
        }
        .onAppear {
            if openRetrospectiveLog {
                selectedTab = .home
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            HomeView()
        case .coach:
            CoachView()
        case .profile:
            ProfileView()
        case .settings:
            SettingsView()
        }
    }
}
