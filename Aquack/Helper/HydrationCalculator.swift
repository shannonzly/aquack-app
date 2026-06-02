//
//  HydrationCalculator.swift
//  Aquack
//

import Foundation

struct HydrationBreakdown: Codable, Equatable {
    /// Weight × gender component shown as "Base (weight × gender)".
    var baseOz: Int
    var weightOz: Int
    var activityOz: Int
    var climateOz: Int
    var stepsOz: Int
    var heatOz: Int
    var habitOz: Int
    var ruleTotalOz: Int
    var totalOz: Int
    var usedClimateEstimate: Bool
}

enum HydrationCalculator {

    static func breakdown(
        for user: UserInfo,
        steps: Double,
        temperatureFahrenheit: Double?
    ) -> HydrationBreakdown {
        let safeWeight = max(0, user.weight)

        let baseFromWeightGender = Int((safeWeight * genderOzPerPound(user.gender)).rounded())
        let activity = activityBonus(for: user.activityLevel)
        let stepBonus = stepBonusOz(steps: steps)
        let heat = temperatureBonusOz(temperatureFahrenheit)

        let ruleTotal = clamp(baseFromWeightGender + activity + stepBonus + heat, 42, 180)
        return HydrationBreakdown(
            baseOz: baseFromWeightGender,
            weightOz: 0,
            activityOz: activity,
            climateOz: 0,
            stepsOz: stepBonus,
            heatOz: heat,
            habitOz: 0,
            ruleTotalOz: ruleTotal,
            totalOz: ruleTotal,
            usedClimateEstimate: false
        )
    }

    static func applyingHabitAdjustment(
        to breakdown: HydrationBreakdown,
        adjustmentOz: Double,
        usedClimateEstimate: Bool
    ) -> HydrationBreakdown {
        var copy = breakdown
        let roundedAdjustment = Int(adjustmentOz.rounded())
        copy.habitOz = roundedAdjustment
        copy.totalOz = clamp(copy.ruleTotalOz + roundedAdjustment, 42, 180)
        copy.usedClimateEstimate = usedClimateEstimate
        return copy
    }

    // MARK: - Components

    private static func genderOzPerPound(_ gender: UserInfo.Gender) -> Double {
        switch gender {
        case .male: return 0.6
        case .female: return 0.5
        case .nonBinary, .preferNotToSay: return 0.55
        }
    }

    private static func activityBonus(for level: UserInfo.ActivityLevel) -> Int {
        switch level {
        case .low: return 8
        case .moderate: return 12
        case .high: return 16
        }
    }

    /// ~12 oz per 10,000 steps.
    private static func stepBonusOz(steps: Double) -> Int {
        guard steps > 0 else { return 0 }
        return max(0, Int((steps / 10_000.0 * 12.0).rounded()))
    }

    private static func temperatureBonusOz(_ tempF: Double?) -> Int {
        guard let tempF else { return 0 }
        switch tempF {
        case ..<60: return 0
        case 60..<70: return 4
        case 70..<80: return 4
        case 80..<90: return 8
        case 90..<100: return 12
        default: return 12
        }
    }

    private static func clamp(_ value: Int, _ minValue: Int, _ maxValue: Int) -> Int {
        min(max(value, minValue), maxValue)
    }
}
