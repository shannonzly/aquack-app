//
//  AppLaunchDefaults.swift
//  Aquack
//

import Foundation

enum AppLaunchDefaults {

    static func register() {
        UserDefaults.standard.register(defaults: [
            "usingRec": true,
            "height": ProfileDefaults.heightCm,
            "weight": ProfileDefaults.weightLb,
            "age": ProfileDefaults.age,
            "gender": ProfileDefaults.gender.rawValue,
            "activityLevel": ProfileDefaults.activityLevel.rawValue,
            "climate": ProfileDefaults.climate.rawValue,
            AppStorageKey.volumeUnit: VolumeUnit.ounces.rawValue,
            AppStorageKey.temperatureUnit: TemperatureUnit.fahrenheit.rawValue,
            AppStorageKey.weightUnit: WeightUnit.pounds.rawValue,
            AppStorageKey.dailyResetMinutes: 0,
            AppStorageKey.forgotToLogEnabled: true,
        ])
    }
}
