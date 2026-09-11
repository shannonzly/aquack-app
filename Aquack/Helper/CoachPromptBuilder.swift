//
//  CoachPromptBuilder.swift
//  Aquack
//

import Foundation

enum CoachPromptBuilder {

    static let systemInstructions = """
        You are Aquack, a friendly hydration coach duck in the Aquack app.
        Give practical, encouraging hydration advice using the user's data below.
        Keep replies to 2-3 short sentences. Be warm and specific — cite their numbers.
        Never give medical advice or diagnose conditions. Use the volume unit provided in the data.
        """

    static func userPrompt(message: String, context: CoachContext) -> String {
        """
        User question: \(message)

        Current hydration data:
        \(contextSummary(context))
        """
    }

    static func openingPrompt(context: CoachContext) -> String {
        """
        Greet the user briefly as Aquack and give one personalized hydration tip based on their data today.
        Do not ask a question unless they have zero intake today.

        Current hydration data:
        \(contextSummary(context))
        """
    }

    static func contextSummary(_ context: CoachContext) -> String {
        let unit = VolumeUnit.current
        let label = unit.abbreviation
        var lines: [String] = []
        lines.append("- Intake today: \(formattedAmount(unit.fromOunces(context.intakeTodayOz))) \(label)")
        lines.append("- Daily goal: \(unit.displayAmount(fromOunces: Double(context.goalTodayOz))) \(label)")
        lines.append("- Remaining: \(unit.displayAmount(fromOunces: Double(context.remainingOz))) \(label)")
        lines.append("- Volume unit: \(label)")

        if context.stepsToday > 0 {
            lines.append("- Steps today: \(Int(context.stepsToday))")
        }
        if let temp = context.temperatureF {
            lines.append("- Local temperature: \(TemperatureUnit.current.displayString(fromFahrenheit: temp))")
        }
        if let lastDrink = context.latestDrinkAt {
            lines.append("- Last drink: \(relativeTime(from: lastDrink))")
        }

        let profile = context.habitProfile
        if profile.daysAnalyzed > 0 {
            lines.append("- 14-day avg intake: \(formattedAmount(unit.fromOunces(profile.averageDailyIntakeOz))) \(label)/day")
            lines.append("- Consistency score: \(Int(profile.consistencyScore * 100))%")
            if profile.longestGapHours >= 2 {
                lines.append("- Longest gap between drinks (recent): \(Int(profile.longestGapHours)) hours")
            }
            if !profile.mostCommonHours.isEmpty {
                let hours = profile.mostCommonHours.map { hourLabel($0) }.joined(separator: ", ")
                lines.append("- Usual drink times: \(hours)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func formattedAmount(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.0f", value)
    }

    private static func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60)) min ago" }
        if interval < 86400 { return "\(Int(interval / 3600)) hr ago" }
        return "earlier today"
    }

    private static func hourLabel(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date).lowercased()
    }
}
