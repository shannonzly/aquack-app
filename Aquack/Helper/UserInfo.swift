//
//  UserInfo.swift
//  Aquack
//

import Foundation

struct UserInfo: Codable, Equatable {
    var height: Double
    var weight: Double
    var age: Int
    var gender: Gender
    var activityLevel: ActivityLevel
    var climate: Climate

    enum Gender: String, CaseIterable, Identifiable, Codable {
        case female = "Female"
        case male = "Male"
        case nonBinary = "Non-binary"
        case preferNotToSay = "Prefer not to say"

        var id: String { rawValue }
    }

    enum ActivityLevel: String, CaseIterable, Identifiable, Codable {
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"

        var id: String { rawValue }

        var multiplier: Double {
            switch self {
            case .low: return 0.95
            case .moderate: return 1.0
            case .high: return 1.1
            }
        }
    }

    enum Climate: String, CaseIterable, Identifiable, Codable {
        case tropical = "Tropical"
        case temperate = "Temperate"
        case cold = "Cold"

        var id: String { rawValue }
    }
}

enum ProfileDefaults {
    static let heightCm = "170"
    static let weightLb = "150"
    static let age = "25"
    static let gender = UserInfo.Gender.preferNotToSay
    static let activityLevel = UserInfo.ActivityLevel.moderate
    static let climate = UserInfo.Climate.temperate

    @MainActor
    static func applyIfEmpty(to rec: Change) {
        if rec.height.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rec.height = heightCm
        }
        if rec.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rec.weight = weightLb
        }
        if rec.age.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rec.age = age
        }
    }
}

