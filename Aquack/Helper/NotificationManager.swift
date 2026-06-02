//
//  NotificationManager.swift
//  Aquack
//

import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let repeatingIdentifier = "aquack.hydration.repeating"
    private let smartPrefix = "aquack.hydration.smart."

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func checkAuthorizationStatus() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    func cancelHydrationReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [repeatingIdentifier])
        let smartIDs = (0..<6).map { "\(smartPrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: smartIDs)
    }

    func scheduleRepeatingNotification(
        title: String,
        body: String,
        intervalMinutes: Int
    ) {
        cancelHydrationReminder()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let safeMinutes = max(30, intervalMinutes)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(safeMinutes * 60), repeats: true)
        let request = UNNotificationRequest(identifier: repeatingIdentifier, content: content, trigger: trigger)
        center.add(request)
    }

    func scheduleSmartReminders(
        profile: HabitProfile,
        title: String,
        body: String
    ) {
        cancelHydrationReminder()
        let targetHours = smartHours(from: profile)
        for (index, hour) in targetHours.enumerated() {
            var date = DateComponents()
            date.hour = hour
            date.minute = 0

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(smartPrefix)\(index)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    func scheduleRepeatingOrSmart(
        smartEnabled: Bool,
        profile: HabitProfile?,
        title: String,
        body: String,
        intervalMinutes: Int
    ) {
        if smartEnabled, let profile {
            scheduleSmartReminders(profile: profile, title: title, body: body)
        } else {
            scheduleRepeatingNotification(title: title, body: body, intervalMinutes: intervalMinutes)
        }
    }

    private func smartHours(from profile: HabitProfile) -> [Int] {
        if profile.mostCommonHours.count >= 2 {
            return Array(profile.mostCommonHours.prefix(3)).sorted()
        }
        return [9, 12, 15, 18]
    }
}

