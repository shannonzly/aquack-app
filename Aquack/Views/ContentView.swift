//
//  ContentView.swift
//  Aquack
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @AppStorage(AppStorageKey.duckCoachEnabled) private var duckCoachEnabled = true

    var body: some View {
        ZStack {
            AmbientPageBackground(bubbleIntensity: 0.35)
                .ignoresSafeArea()

            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 8) {
            GlassTabBar(selection: $selectedTab, showCoach: duckCoachEnabled)
        }
        .onChange(of: duckCoachEnabled) { _, enabled in
            if !enabled, selectedTab == .coach {
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
