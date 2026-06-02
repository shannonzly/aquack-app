//
//  AppReset.swift
//  Aquack
//
//  Clears saved preferences so the app behaves like a fresh install.
//

import Foundation

enum AppReset {

    static func clearAllSavedState() {
        let keys = [
            "didFinishTutorial",
            "goalAmount",
            "recommendedAmount",
            "height", "weight", "age", "gender", "activityLevel", "climate",
            "usingRec",
            "dailyIntake",
            "lastResetDate",
            "lastStepsToday",
            "lastWeatherTempF",
            AppStorageKey.healthStepsEnabled,
            AppStorageKey.locationWeatherEnabled,
            AppStorageKey.lastWeatherKitFetchDate,
            AppStorageKey.cachedWeatherKitTempF,
            AppStorageKey.cachedWeatherLatitude,
            AppStorageKey.cachedWeatherLongitude,
            AppStorageKey.lastHydrationSyncDate,
            AppStorageKey.notificationsUserEnabled,
            AppStorageKey.lastBreakdown,
            AppStorageKey.lastBreakdownUsedSteps,
            AppStorageKey.lastBreakdownUsedWeather,
            AppStorageKey.personalizedGoalEnabled,
            AppStorageKey.smartRemindersEnabled,
            AppStorageKey.duckCoachEnabled,
            "notificationTitle",
            "notificationBody",
            "notificationsInterval"
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
