//
//  WaterView.swift
//  Adding water level
//  Aquack
//

import SwiftData
import SwiftUI

private struct BuiltInDrink: Identifiable {
    let id: String
    let name: String
    let ounces: Double
}

struct WaterView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKey.volumeUnit) private var volumeUnitRaw = VolumeUnit.ounces.rawValue

    @State private var customAmount = ""
    @State private var saveName = ""
    @State private var showSaveForm = false
    @State private var customDrinks: [CustomDrinkSize] = CustomDrinkSizeStore.load()
    @State private var whenPreset: LogWhenPreset = .justNow
    @State private var selectedTime = Date()
    @State private var isEditingCustoms = false

    /// When true, default the When picker toward retrospective options.
    var openForRetrospective: Bool = false
    var onLogged: () -> Void
    var onBack: () -> Void

    private var volumeUnit: VolumeUnit { VolumeUnit(rawValue: volumeUnitRaw) ?? .ounces }

    private let builtIns: [BuiltInDrink] = [
        BuiltInDrink(id: "glass", name: "Small Glass", ounces: 8),
        BuiltInDrink(id: "bottle", name: "Bottle", ounces: 16),
        BuiltInDrink(id: "coffee", name: "Coffee / Tea", ounces: 6)
    ]

    private var dayStart: Date { DailyResetPreference.dayStart() }
    private var canAddCustom: Bool {
        guard let value = Double(customAmount), value > 0 else { return false }
        return true
    }

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
                        title: openForRetrospective ? "Log earlier" : "Log water",
                        subtitle: openForRetrospective
                            ? "Add a drink from earlier today"
                            : "Every splash counts toward your goal",
                        systemImage: "drop.fill"
                    )

                    whenSection

                    GlassCard {
                        GlassInsetField(
                            label: "Custom amount (\(volumeUnit.abbreviation))",
                            text: $customAmount,
                            keyboard: .decimalPad
                        )
                    }

                    CapsuleSectionHeader(title: "Quick add", systemImage: "bolt.fill")

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(builtIns) { option in
                            QuickAddCard(
                                title: option.name,
                                amountLabel: amountLabel(ounces: option.ounces),
                                showsDelete: false
                            ) {
                                addWater(option.ounces, note: option.name, source: logSource)
                            }
                        }
                        ForEach(customDrinks) { drink in
                            QuickAddCard(
                                title: drink.name,
                                amountLabel: amountLabel(ounces: drink.ounces),
                                showsDelete: isEditingCustoms
                            ) {
                                if isEditingCustoms {
                                    CustomDrinkSizeStore.delete(id: drink.id)
                                    customDrinks = CustomDrinkSizeStore.load()
                                    let goal = UserDefaults.standard.string(forKey: "goalAmount")?.ozAmountInt ?? 64
                                    WidgetSnapshotSync.publishFromContext(context: modelContext, goalOz: goal)
                                } else {
                                    addWater(drink.ounces, note: drink.name, source: logSource)
                                }
                            }
                        }
                    }

                    if !customDrinks.isEmpty {
                        Button {
                            isEditingCustoms.toggle()
                        } label: {
                            Text(isEditingCustoms ? "Done editing" : "Edit custom sizes")
                                .font(HydrationTypography.body)
                                .foregroundStyle(HydrationTheme.label)
                        }
                        .buttonStyle(.plain)
                    }

                    PrimaryWaterButton(title: "Add custom amount", disabled: !canAddCustom) {
                        guard let value = Double(customAmount), value > 0 else { return }
                        addWater(volumeUnit.toOunces(value), note: nil, source: logSource)
                    }

                    if canAddCustom {
                        Button {
                            showSaveForm.toggle()
                            if saveName.isEmpty, let value = Double(customAmount) {
                                saveName = "\(volumeUnit.displayAmount(fromOunces: volumeUnit.toOunces(value))) \(volumeUnit.abbreviation)"
                            }
                        } label: {
                            Text(showSaveForm ? "Cancel save" : "Save as drink size")
                                .font(HydrationTypography.body)
                                .foregroundStyle(HydrationTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    if showSaveForm, canAddCustom {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                GlassInsetField(label: "Name", text: $saveName)
                                PrimaryWaterButton(title: "Save size", disabled: saveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                                    guard let value = Double(customAmount), value > 0 else { return }
                                    CustomDrinkSizeStore.add(name: saveName, ounces: volumeUnit.toOunces(value))
                                    customDrinks = CustomDrinkSizeStore.load()
                                    showSaveForm = false
                                    saveName = ""
                                    let goal = UserDefaults.standard.string(forKey: "goalAmount")?.ozAmountInt ?? 64
                                    WidgetSnapshotSync.publishFromContext(context: modelContext, goalOz: goal)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .hydrationPageContent()
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            customDrinks = CustomDrinkSizeStore.load()
            selectedTime = Date()
            if openForRetrospective {
                whenPreset = .oneHourAgo
            }
        }
    }

    private var logSource: String {
        whenPreset == .justNow ? "manual" : "retrospective"
    }

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            CapsuleSectionHeader(title: "When?", systemImage: "clock")

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    FlowWhenChips(selection: $whenPreset)

                    if whenPreset == .selectTime {
                        DatePicker(
                            "Time",
                            selection: $selectedTime,
                            in: dayStart...Date(),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                    } else {
                        Text(previewWhenLabel)
                            .hydrationFootnote()
                    }
                }
            }
        }
    }

    private var previewWhenLabel: String {
        let date = whenPreset.date(selectedTime: selectedTime)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "Logs as \(formatter.string(from: date))"
    }

    private func amountLabel(ounces: Double) -> String {
        "\(volumeUnit.displayAmount(fromOunces: ounces)) \(volumeUnit.abbreviation)"
    }

    private func addWater(_ ounces: Double, note: String?, source: String) {
        let at = whenPreset.date(selectedTime: selectedTime)
        HydrationHistoryStore.log(
            ounces: ounces,
            context: modelContext,
            at: at,
            source: source,
            note: note
        )
        onLogged()
        onBack()
    }
}

private struct FlowWhenChips: View {
    @Binding var selection: LogWhenPreset

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(LogWhenPreset.allCases) { preset in
                Button {
                    selection = preset
                } label: {
                    Text(preset.label)
                        .font(HydrationTypography.footnoteEmphasis)
                        .foregroundStyle(selection == preset ? Color.white : HydrationTheme.title)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            selection == preset ? HydrationTheme.accent : HydrationTheme.accentSoft.opacity(0.35),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct QuickAddCard: View {
    let title: String
    let amountLabel: String
    var showsDelete: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: showsDelete ? "trash.fill" : "drop.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(showsDelete ? Color.red : HydrationTheme.accent)
                        .frame(width: 40, height: 40)
                        .background(
                            (showsDelete ? Color.red.opacity(0.15) : HydrationTheme.accentSoft.opacity(0.35)),
                            in: Circle()
                        )
                }
                Text(title)
                    .font(HydrationTypography.bodyEmphasis)
                    .foregroundStyle(HydrationTheme.title)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(amountLabel)
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
