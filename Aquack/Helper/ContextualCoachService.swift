//
//  ContextualCoachService.swift
//  Aquack
//

import Foundation

enum ContextualCoachService {

    static func openingMessage(context: CoachContext) -> String {
        if context.intakeTodayOz <= 1 {
            return "Hey! Start with an easy 8 oz sip and I'll help pace the rest of your day."
        }
        if context.remainingOz == 0 {
            return "You hit your \(context.goalTodayOz) oz goal today — great consistency!"
        }
        let pct = Int((context.intakeTodayOz / Double(max(context.goalTodayOz, 1))) * 100)
        return "You're at \(Int(context.intakeTodayOz)) / \(context.goalTodayOz) oz (\(pct)%). \(nextSipSuggestion(context))"
    }

    static func reply(to userMessage: String, context: CoachContext) -> String {
        let message = userMessage.lowercased()

        if matches(message, any: ["how am i", "how's my", "how is my", "doing today", "progress"]) {
            return progressSummary(context)
        }
        if matches(message, any: ["when should", "when to drink", "drink next", "next sip", "next drink"]) {
            return nextDrinkAdvice(context)
        }
        if matches(message, any: ["goal", "why"]) && matches(message, any: ["set", "this way", "so high", "so low", "why"]) {
            return goalExplanation(context)
        }
        if matches(message, any: ["how much", "remaining", "left today", "left to drink"]) {
            return "You have about \(context.remainingOz) oz left today. Try splitting it into 3–4 small sips."
        }
        if matches(message, any: ["reminder", "remind", "notification"]) {
            return reminderAdvice(context)
        }
        if matches(message, any: ["habit", "consistent", "consistency", "pattern"]) {
            return habitInsight(context)
        }
        if let temp = context.temperatureF, temp >= 85, matches(message, any: ["hot", "warm", "weather", "heat", "temperature"]) {
            return "It's warm out (\(Int(temp))°F). Add an extra 8–12 oz this afternoon and sip more often."
        }
        if context.habitProfile.longestGapHours >= 4, matches(message, any: ["gap", "forget", "behind", "catch up"]) {
            return "I noticed long gaps between drinks. Aim for a sip every 60–90 minutes — even 6 oz counts."
        }
        if context.remainingOz == 0 {
            return "You're done for today! A light sip before bed is optional, but you've already nailed your goal."
        }
        return "Nice check-in. \(nextSipSuggestion(context))"
    }

    // MARK: - Reply builders

    private static func progressSummary(_ context: CoachContext) -> String {
        let intake = Int(context.intakeTodayOz)
        let goal = context.goalTodayOz
        let pct = Int((context.intakeTodayOz / Double(max(goal, 1))) * 100)

        if context.remainingOz == 0 {
            return "You're at \(intake)/\(goal) oz — goal complete! Your consistency over the past 2 weeks is \(consistencyLabel(context))."
        }

        var parts = ["You're at \(intake)/\(goal) oz (\(pct)%), with \(context.remainingOz) oz to go."]
        if let last = context.latestDrinkAt {
            parts.append("Last drink was \(relativeTime(from: last)).")
        }
        parts.append(nextSipSuggestion(context))
        return parts.joined(separator: " ")
    }

    private static func nextDrinkAdvice(_ context: CoachContext) -> String {
        if context.remainingOz == 0 {
            return "You're all set for today! If you want one more, a small 4–6 oz sip is fine."
        }

        let sipOz = min(12, max(6, context.remainingOz / max(3, context.remainingOz / 8)))
        var advice = "Try \(sipOz) oz now"

        if let last = context.latestDrinkAt {
            let hoursSince = Date().timeIntervalSince(last) / 3600
            if hoursSince >= 2 {
                advice = "It's been \(Int(hoursSince)) hours since your last drink — \(advice.lowercased())"
            } else {
                advice += ", then another in about \(max(1, 2 - Int(hoursSince))) hour(s)"
            }
        } else {
            advice += " to get started"
        }

        let profile = context.habitProfile
        if !profile.mostCommonHours.isEmpty {
            let nextHour = profile.mostCommonHours.first { $0 > Calendar.current.component(.hour, from: Date()) }
            if let nextHour {
                advice += ". You usually drink around \(hourLabel(nextHour)) too"
            }
        }

        return advice + "."
    }

    private static func goalExplanation(_ context: CoachContext) -> String {
        var factors = ["your profile (weight, activity, climate)"]
        if context.stepsToday > 5000 {
            factors.append("today's \(Int(context.stepsToday)) steps")
        }
        if let temp = context.temperatureF, temp >= 80 {
            factors.append("the \(Int(temp))°F weather")
        }
        if context.habitProfile.daysAnalyzed >= 3 {
            factors.append("your recent drinking habits")
        }
        let factorList = factors.joined(separator: ", ")
        return "Your \(context.goalTodayOz) oz goal blends \(factorList). It adjusts as your activity and habits change."
    }

    private static func reminderAdvice(_ context: CoachContext) -> String {
        let profile = context.habitProfile
        if profile.daysAnalyzed < 3 {
            return "Log a few more days and I'll learn your rhythm. For now, try reminders every 2 hours during waking hours."
        }
        if !profile.mostCommonHours.isEmpty {
            let hours = profile.mostCommonHours.map { hourLabel($0) }.joined(separator: ", ")
            return "Based on your habits, reminders around \(hours) work well. Pair them with your usual drink times."
        }
        return "Smart reminders work best when you log consistently. Try 2–3 nudges spread across your day."
    }

    private static func habitInsight(_ context: CoachContext) -> String {
        let profile = context.habitProfile
        guard profile.daysAnalyzed >= 3 else {
            return "Keep logging for a few more days and I'll spot your patterns. Consistency builds from small, regular sips."
        }
        let avg = Int(profile.averageDailyIntakeOz)
        let label = consistencyLabel(context)
        if profile.longestGapHours >= 4 {
            return "You average \(avg) oz/day with \(label) consistency, but gaps over \(Int(profile.longestGapHours)) hours show up. Shorter, more frequent sips would help."
        }
        return "Over the last \(profile.daysAnalyzed) days you average \(avg) oz/day — \(label) consistency. \(nextSipSuggestion(context))"
    }

    private static func nextSipSuggestion(_ context: CoachContext) -> String {
        if context.remainingOz == 0 { return "You're all set for today." }
        let sip = min(12, max(6, context.remainingOz / 3))
        return "A quick \(sip) oz sip now would keep you on track."
    }

    private static func consistencyLabel(_ context: CoachContext) -> String {
        switch context.habitProfile.consistencyScore {
        case 0.8...: return "strong"
        case 0.6..<0.8: return "solid"
        case 0.4..<0.6: return "building"
        default: return "early"
        }
    }

    // MARK: - Helpers

    private static func matches(_ message: String, any phrases: [String]) -> Bool {
        phrases.contains { message.contains($0) }
    }

    private static func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60)) min ago" }
        return "\(Int(interval / 3600)) hr ago"
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
