// SettingsInfo.swift — Reminder interval and goal type enums for pickers.

import Foundation

struct SettingsInfo {
    var timeInterval: Interval
    var dailyGoal: Goal
    
    enum Goal: String, CaseIterable, Identifiable {
        case rec = "Use recommended amount"
        case custom = "Custom"
        
        var id: String { rawValue }

        /// Short label for segmented controls.
        var segmentedLabel: String {
            switch self {
            case .rec: return "Recommended"
            case .custom: return "Custom"
            }
        }
    }
    
    enum Interval: String, CaseIterable, Identifiable {
        case half = "30 minutes"
        case one = "1 hour"
        case oneandhalf = "1.5 hours"
        case two = "2 hours"
        case twoandhalf = "2.5 hours"
        case three = "3 hours"
        case threeandhalf = "3.5 hours"
        case four = "4 hours"
        case fourandhalf = "4.5 hours"
        case five = "5 hours"

        var id: String { rawValue }

        var timeIntervalInSeconds: TimeInterval {
            switch self {
            case .half: return 30 * 60
            case .one: return 60 * 60
            case .oneandhalf: return 90 * 60
            case .two: return 2 * 60 * 60
            case .twoandhalf: return 2.5 * 60 * 60
            case .three: return 3 * 60 * 60
            case .threeandhalf: return 3.5 * 60 * 60
            case .four: return 4 * 60 * 60
            case .fourandhalf: return 4.5 * 60 * 60
            case .five: return 5 * 60 * 60
            }
        }
    }
        
}
