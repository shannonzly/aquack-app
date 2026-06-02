//
//  CoachContextBuilder.swift
//  Aquack
//

import Foundation
import SwiftData

struct CoachContext {
    var intakeTodayOz: Double
    var goalTodayOz: Int
    var remainingOz: Int
    var stepsToday: Double
    var temperatureF: Double?
    var latestDrinkAt: Date?
    var habitProfile: HabitProfile
}

enum CoachContextBuilder {

    @MainActor
    static func build(rec: Change, context: ModelContext) -> CoachContext {
        let intake = HydrationHistoryStore.todayIntakeOz(context: context)
        let goal = max(1, rec.goalAmount.ozAmountInt)
        let profile = HabitAnalyzer.analyze(context: context, goalOz: goal)
        let recent = HydrationHistoryStore.entriesForLastDays(1, context: context).last?.timestamp

        return CoachContext(
            intakeTodayOz: intake,
            goalTodayOz: goal,
            remainingOz: max(0, goal - Int(intake.rounded())),
            stepsToday: rec.lastStepsToday,
            temperatureF: rec.lastWeatherTempF,
            latestDrinkAt: recent,
            habitProfile: profile
        )
    }
}

