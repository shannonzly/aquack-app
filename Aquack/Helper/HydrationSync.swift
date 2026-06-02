//
//  HydrationSync.swift
//  Aquack
//

import Foundation
import SwiftData

enum AquackCopy {
    static let defaultNotificationTitle = "Aquack says: Sip!"
    static let defaultNotificationBody = "Keep reaching that daily goal!"
}

enum AppStorageKey {
    static let healthStepsEnabled = "healthKitEnabled"
    static let locationWeatherEnabled = "locationWeatherEnabled"
    static let lastWeatherKitFetchDate = "lastWeatherKitFetchDate"
    static let cachedWeatherKitTempF = "cachedWeatherKitTempF"
    static let cachedWeatherLatitude = "cachedWeatherLatitude"
    static let cachedWeatherLongitude = "cachedWeatherLongitude"
    static let lastHydrationSyncDate = "lastHydrationSyncDate"
    static let notificationsUserEnabled = "notificationsUserEnabled"
    static let lastBreakdown = "lastHydrationBreakdown"
    static let lastBreakdownUsedSteps = "lastBreakdownUsedHealth"
    static let lastBreakdownUsedWeather = "lastBreakdownUsedWeather"
    static let personalizedGoalEnabled = "personalizedGoalEnabled"
    static let smartRemindersEnabled = "smartRemindersEnabled"
    static let duckCoachEnabled = "duckCoachEnabled"
}

extension String {
    var ozAmountInt: Int {
        let digits = filter(\.isNumber)
        guard !digits.isEmpty else { return 0 }
        return Int(digits) ?? 0
    }

    var ozAmountDouble: Double { Double(ozAmountInt) }

    var normalizedOzString: String {
        let n = ozAmountInt
        return n > 0 ? "\(n)" : "64"
    }
}

enum HydrationSync {

    @MainActor
    static func refresh(
        recommendation rec: Change,
        modelContext: ModelContext? = nil,
        force: Bool = false
    ) async {
        if !force,
           let last = UserDefaults.standard.object(forKey: AppStorageKey.lastHydrationSyncDate) as? Date,
           Calendar.current.isDateInToday(last),
           Date().timeIntervalSince(last) < 300 {
            return
        }

        let user = UserInfo(
            height: Double(rec.height) ?? 0,
            weight: Double(rec.weight) ?? 0,
            age: Int(rec.age) ?? 0,
            gender: rec.gender,
            activityLevel: rec.activityLevel,
            climate: rec.climate
        )

        let stepsEnabled = UserDefaults.standard.bool(forKey: AppStorageKey.healthStepsEnabled)
        let wantsWeather = UserDefaults.standard.bool(forKey: AppStorageKey.locationWeatherEnabled)
        let locationEnabled = wantsWeather && LocationManager.shared.isAuthorized
        let personalizedGoal = UserDefaults.standard.object(forKey: AppStorageKey.personalizedGoalEnabled) as? Bool ?? true

        var steps: Double = 0
        if stepsEnabled {
            steps = await HealthManager.shared.fetchTodaySteps()
            if steps == 0, rec.lastStepsToday > 0 {
                steps = rec.lastStepsToday
            }
            rec.lastStepsToday = steps
        } else {
            rec.lastStepsToday = 0
        }

        let tempResolution = await TemperatureResolver.resolve(
            for: rec,
            locationEnabled: locationEnabled,
            forceRefresh: force
        )
        let tempF = tempResolution.fahrenheit
        switch tempResolution.source {
        case .liveWeather:
            rec.lastWeatherTempF = tempF
        case .climateEstimate:
            rec.lastWeatherTempF = tempF
        }

        var breakdown = HydrationCalculator.breakdown(for: user, steps: steps, temperatureFahrenheit: tempF)
        breakdown.usedClimateEstimate = tempResolution.source == .climateEstimate

        if personalizedGoal, let ctx = modelContext {
            let habitProfile = HabitAnalyzer.analyze(context: ctx, goalOz: rec.goalAmount.ozAmountInt)
            let adjustment = HabitAnalyzer.habitAdjustmentOz(for: habitProfile)
            let finalOz = GoalPredictionModel.predictedGoalOz(
                ruleTotal: breakdown.ruleTotalOz,
                habitAdjustment: adjustment,
                profile: habitProfile
            )
            breakdown = HydrationCalculator.applyingHabitAdjustment(
                to: breakdown,
                adjustmentOz: Double(finalOz - breakdown.ruleTotalOz),
                usedClimateEstimate: breakdown.usedClimateEstimate
            )
        }

        rec.recommendedAmount = "\(breakdown.totalOz)"
        if rec.usingRec {
            rec.goalAmount = "\(breakdown.totalOz)"
        }

        if let data = try? JSONEncoder().encode(breakdown) {
            UserDefaults.standard.set(data, forKey: AppStorageKey.lastBreakdown)
        }
        UserDefaults.standard.set(stepsEnabled, forKey: AppStorageKey.lastBreakdownUsedSteps)
        UserDefaults.standard.set(
            tempResolution.source == .liveWeather,
            forKey: AppStorageKey.lastBreakdownUsedWeather
        )

        if let ctx = modelContext {
            let smartReminders = UserDefaults.standard.object(forKey: AppStorageKey.smartRemindersEnabled) as? Bool ?? true
            let userWantsNotifs = UserDefaults.standard.bool(forKey: AppStorageKey.notificationsUserEnabled)
            if smartReminders && userWantsNotifs {
                let profile = HabitAnalyzer.analyze(context: ctx, goalOz: rec.goalAmount.ozAmountInt)
                let title = UserDefaults.standard.string(forKey: "notificationTitle") ?? AquackCopy.defaultNotificationTitle
                let body = UserDefaults.standard.string(forKey: "notificationBody") ?? AquackCopy.defaultNotificationBody
                NotificationManager.shared.scheduleSmartReminders(
                    profile: profile,
                    title: title,
                    body: body
                )
            }
        }

        UserDefaults.standard.set(Date(), forKey: AppStorageKey.lastHydrationSyncDate)
    }
}
