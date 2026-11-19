import Foundation
import UIKit
import UserNotifications
import BackgroundTasks
import Postbox
import TelegramCore

/// Local notifications for builds that cannot receive APNs pushes.
///
/// A re-signed AyuGram build owns neither Telegram's APNs topic nor a push
/// certificate, so `registerForRemoteNotifications()` never produces a token and
/// the server never delivers anything. Everything here is generated on-device
/// from messages the app has already processed.
public enum AyuGramLocalNotifications {
    private static var isRussian: Bool {
        let code = (Locale.preferredLanguages.first ?? "en").lowercased()
        return code.hasPrefix("ru") || code.hasPrefix("uk") || code.hasPrefix("be") || code.hasPrefix("kk")
    }

    private static func localized(_ russian: String, _ english: String) -> String {
        return self.isRussian ? russian : english
    }

    public static var refreshTaskIdentifier: String {
        let base = Bundle.main.bundleIdentifier ?? "org.telegram.Telegram"
        return base + ".refresh"
    }

    public static func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    private static let backgroundObserver: NSObjectProtocol? = {
        return NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            AyuGramLocalNotifications.scheduleBackgroundRefresh()
        }
    }()

    public static func registerBackgroundRefresh() {
        _ = self.backgroundObserver
        _ = BGTaskScheduler.shared.register(forTaskWithIdentifier: self.refreshTaskIdentifier, using: DispatchQueue.main) { task in
            AyuGramLocalNotifications.scheduleBackgroundRefresh()
            task.expirationHandler = {
                task.setTaskCompleted(success: false)
            }
            // The accounts reconnect and replay pending updates during launch;
            // holding the task briefly gives them time to deliver messages.
            DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
                task.setTaskCompleted(success: true)
            }
        }
    }

    public static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: self.refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15.0 * 60.0)
        // A rejected request is harmless: the identifier is declared in the app
        // plist, and the system decides whether it ever runs.
        try? BGTaskScheduler.shared.submit(request)
    }

    public static func postTest() {
        self.requestAuthorization(completion: { granted in
            guard granted else {
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "AyuGram"
            content.body = AyuGramLocalNotifications.localized("Уведомления работают", "Notifications are working")
            content.sound = .default
            let request = UNNotificationRequest(identifier: "ayugram.test", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        })
    }

    /// Called for incoming messages while the app is not in the foreground.
    public static func post(message: Message, chatTitle: String, isMuted: Bool) {
        guard AyuGramSettings.localNotificationsEnabled, !isMuted else {
            return
        }
        guard AyuGramSettings.notificationEnabled(AyuGramSettings.category(message: message)) else {
            return
        }

        let content = UNMutableNotificationContent()
        if AyuGramSettings.hideNotificationContent {
            content.title = "AyuGram"
            content.body = AyuGramLocalNotifications.localized("Новое сообщение", "New message")
        } else {
            let authorTitle = message.author?.debugDisplayTitle ?? ""
            content.title = chatTitle.isEmpty ? "AyuGram" : chatTitle
            let preview: String
            if !message.text.isEmpty {
                preview = String(message.text.prefix(240))
            } else if !message.media.isEmpty {
                preview = AyuGramLocalNotifications.localized("[медиа]", "[media]")
            } else {
                preview = AyuGramLocalNotifications.localized("Новое сообщение", "New message")
            }
            if !authorTitle.isEmpty, authorTitle != chatTitle {
                content.body = authorTitle + ": " + preview
            } else {
                content.body = preview
            }
        }
        content.sound = .default
        content.threadIdentifier = "ayugram.\(message.id.peerId.toInt64())"
        content.userInfo = [
            "peerId": message.id.peerId.toInt64(),
            "messageId": message.id.id
        ]

        let identifier = "ayugram.message.\(message.id.peerId.toInt64()).\(message.id.namespace).\(message.id.id)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
