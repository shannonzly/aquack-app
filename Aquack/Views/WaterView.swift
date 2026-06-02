//
//  WaterView.swift
//  Adding water level
//  Aquack
//

import SwiftData
import SwiftUI

private struct QuickAddOption: Identifiable {
    let id = UUID()
    let name: String
    let ounces: Double
}

struct WaterView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var customOz = ""
    var onLogged: () -> Void
    var onBack: () -> Void

    private let quickOptions: [QuickAddOption] = [
        QuickAddOption(name: "Small Glass", ounces: 8),
        QuickAddOption(name: "Bottle", ounces: 16),
        QuickAddOption(name: "Coffee / Tea", ounces: 6)
    ]

    var body: some View {
        HydrationPageShell(interactive: true, bubbleIntensity: 0.65) {
            KeyboardDismissingScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        BackPillButton(action: onBack)
                        Spacer()
                    }
                    .padding(.top, 4)

                    PageHeroHeader(
                        title: "Log water",
                        subtitle: "Every splash counts toward your goal",
                        systemImage: "drop.fill"
                    )

                    GlassCard {
                        GlassInsetField(label: "Custom amount (oz)", text: $customOz, keyboard: .decimalPad)
                    }

                    CapsuleSectionHeader(title: "Quick add", systemImage: "bolt.fill")

                    HStack(spacing: 12) {
                        ForEach(quickOptions) { option in
                            QuickAddCard(option: option) {
                                addWater(option.ounces)
                            }
                        }
                    }

                    PrimaryWaterButton(title: "Add custom amount", disabled: !canAddCustom) {
                        guard let value = Double(customOz), value > 0 else { return }
                        addWater(value)
                    }

                    Spacer(minLength: 40)
                }
                .hydrationPageContent()
                .padding(.bottom, 28)
            }
        }
    }

    private var canAddCustom: Bool {
        guard let value = Double(customOz), value > 0 else { return false }
        return true
    }

    private func addWater(_ ounces: Double) {
        HydrationHistoryStore.log(ounces: ounces, context: modelContext)
        onLogged()
        onBack()
    }
}

private struct QuickAddCard: View {
    let option: QuickAddOption
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: "drop.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(HydrationTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(HydrationTheme.accentSoft.opacity(0.35), in: Circle())
                Text(option.name)
                    .font(HydrationTypography.bodyEmphasis)
                    .foregroundStyle(HydrationTheme.title)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("\(Int(option.ounces)) oz")
                    .font(HydrationTypography.footnote)
                    .foregroundStyle(HydrationTheme.label)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .glassSurface(cornerRadius: 18)
        }
        .buttonStyle(.plain)
    }
}
