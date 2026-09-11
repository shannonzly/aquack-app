//
//  NotificationManager.swift
//  Aquack
//

import Foundation
import UserNotifications

enum AquackNotification {
    static let forgotCategoryID = "aquack.forgot_to_log"
    static let forgotActionID = "aquack.forgot_to_log.action"
    static let forgotRequestID = "aquack.hydration.forgot"
    static let userInfoOpenRetroKey = "openRetrospectiveLog"
}

final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let repeatingIdentifier = "aquack.hydration.repeating"
    private let smartPrefix = "aquack.hydration.smart."

    private override init() {
        super.init()
    }

    func configureDelegate() {
        center.delegate = self
        registerCategories()
    }

    func registerCategories() {
        let logEarlier = UNNotificationAction(
            identifier: AquackNotification.forgotActionID,
            title: "Log earlier drink",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: AquackNotification.forgotCategoryID,
            actions: [logEarlier],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

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

    func cancelForgotToLogReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [AquackNotification.forgotRequestID])
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
        refreshForgotToLogReminder()
    }

    /// Afternoon nudge inviting retrospective logging (defaults to 3:30 PM local).
    func scheduleForgotToLogReminder(enabled: Bool, hour: Int = 15, minute: Int = 30) {
        cancelForgotToLogReminder()
        guard enabled else { return }

        var date = DateComponents()
        date.hour = hour
        date.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "Forgot to log?"
        content.body = "Quickly add a drink from earlier today—no exact time needed."
        content.sound = .default
        content.categoryIdentifier = AquackNotification.forgotCategoryID
        content.userInfo = [AquackNotification.userInfoOpenRetroKey: true]

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(
            identifier: AquackNotification.forgotRequestID,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func refreshForgotToLogReminder() {
        let userWantsNotifs = UserDefaults.standard.bool(forKey: AppStorageKey.notificationsUserEnabled)
        let forgotEnabled = UserDefaults.standard.object(forKey: AppStorageKey.forgotToLogEnabled) as? Bool ?? true
        scheduleForgotToLogReminder(enabled: userWantsNotifs && forgotEnabled)
    }

    private func smartHours(from profile: HabitProfile) -> [Int] {
        if profile.mostCommonHours.count >= 2 {
            return Array(profile.mostCommonHours.prefix(3)).sorted()
        }
        return [9, 12, 15, 18]
    }

    private func handleForgotOpen() {
        UserDefaults.standard.set(true, forKey: AppStorageKey.openRetrospectiveLog)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let isForgot = response.notification.request.content.categoryIdentifier == AquackNotification.forgotCategoryID
            || response.notification.request.identifier == AquackNotification.forgotRequestID
            || (info[AquackNotification.userInfoOpenRetroKey] as? Bool == true)

        if isForgot {
            switch response.actionIdentifier {
            case AquackNotification.forgotActionID, UNNotificationDefaultActionIdentifier:
                handleForgotOpen()
            default:
                break
            }
        }
        completionHandler()
    }
}
