//
//  GlassTabBar.swift
//  Glass controls, appears on every page
//  Aquack
//

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case coach
    case profile
    case settings

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "drop.fill"
        case .coach: return "bubble.left.and.bubble.right.fill"
        case .profile: return "target"
        case .settings: return "gearshape.fill"
        }
    }
}

private enum TabBarMetrics {
    static let cornerRadius: CGFloat = 30
    static let horizontalInset: CGFloat = 22
    static let barHeight: CGFloat = 58
    static let activeIndicatorSize: CGFloat = 38
    static let floatSpacing: CGFloat = 8
}

private struct FloatingTabBarSurface: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(HydrationTheme.glassFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(HydrationTheme.glassStroke, lineWidth: 1)
                    }
                    .shadow(color: HydrationTheme.accent.opacity(0.12), radius: 16, y: 8)
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
            }
    }
}

private extension View {
    func floatingTabBarSurface(cornerRadius: CGFloat = TabBarMetrics.cornerRadius) -> some View {
        modifier(FloatingTabBarSurface(cornerRadius: cornerRadius))
    }
}

struct GlassTabBar: View {
    @Binding var selection: AppTab
    var showCoach: Bool = true

    private var visibleTabs: [AppTab] {
        showCoach ? AppTab.allCases : AppTab.allCases.filter { $0 != .coach }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(visibleTabs) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = tab
                    }
                } label: {
                    ZStack {
                        if selection == tab {
                            Circle()
                                .fill(HydrationTheme.accentSoft.opacity(0.38))
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.5)
                                }
                                .frame(
                                    width: TabBarMetrics.activeIndicatorSize,
                                    height: TabBarMetrics.activeIndicatorSize
                                )
                        }
                        GradientIconStyle(
                            systemName: tab.icon,
                            size: 15,
                            active: selection == tab
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: TabBarMetrics.barHeight)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .floatingTabBarSurface()
        .padding(.horizontal, TabBarMetrics.horizontalInset)
    }
}
