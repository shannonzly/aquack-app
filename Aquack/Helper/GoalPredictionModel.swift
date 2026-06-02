//
//  GoalPredictionModel.swift
//  Aquack
//

import Foundation

enum GoalPredictionModel {

    static func predictedGoalOz(
        ruleTotal: Int,
        habitAdjustment: Int,
        profile: HabitProfile
    ) -> Int {
        let confidence = min(1.0, max(0.0, profile.consistencyScore))
        let taperedAdjustment = Int((Double(habitAdjustment) * confidence).rounded())
        return clamp(ruleTotal + taperedAdjustment, 42, 180)
    }

    private static func clamp(_ value: Int, _ minValue: Int, _ maxValue: Int) -> Int {
        min(max(value, minValue), maxValue)
    }
}

