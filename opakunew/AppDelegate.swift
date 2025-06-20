import UIKit
import FirebaseCore // For FirebaseApp.configure()
import FirebaseMessaging
import UserNotifications
import AmplitudeSwift
import FirebaseRemoteConfig
import FirebaseAnalytics // Explicitly import FirebaseAnalytics for constants like AnalyticsParameterContentType

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    let sharedAmplitude = Amplitude(
        configuration: Configuration(
            apiKey: "YOUR_AMPLITUDE_API_KEY"
        )
    )

    var fcmTokenString: String?
    var window: UIWindow?

    var remoteConfig: RemoteConfig!

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        FirebaseApp.configure()

        remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings

        remoteConfig.setDefaults([
            "firebase_blocked_events": "" as NSObject
        ])

        _ = AnalyticsManager.shared

        UNUserNotificationCenter.current().delegate = self

        Messaging.messaging().delegate = self
        Messaging.messaging().subscribe(toTopic: "promoMay")

        return true
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        print("Notifikasi remote diterima (mungkin di background): \(userInfo)")

        let isSilentPush = (userInfo["aps"] as? [String: AnyObject])?["content-available"] as? Int == 1

        // Safely convert userInfo to [String: Any]
        var eventParams: [String: Any] = userInfo.reduce(into: [String: Any]()) { result, entry in
            if let key = entry.key as? String {
                result[key] = entry.value
            }
        }

        eventParams["trigger_point"] = "background_data_receive"
        eventParams["is_silent_push"] = isSilentPush
        // Use AnalyticsParameterContentType correctly if the key truly is a string
        eventParams[AnalyticsParameterContentType] = "notification"


        // You already have if let customData, no need to redefine
        // if let notificationId = userInfo["gcm.message_id"] as? String {
        //     eventParams["notification_id"] = notificationId
        // }
        // if let customData = userInfo["custom_key"] as? String {
        //     eventParams["custom_payload_data"] = customData
        // }


        Task {
            await AnalyticsManager.shared.logEvent(eventName: "notification_processed", parameters: eventParams)
            print("AnalyticsManager logged 'notification_processed' (background data).")
            completionHandler(.newData)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("ℹ️ Notifikasi diterima di foreground: \(userInfo)")

        completionHandler([[.alert, .sound, .badge]])

        // Safely convert userInfo to [String: Any] for logging
        let loggableUserInfo: [String: Any] = userInfo.reduce(into: [String: Any]()) { result, entry in
            if let key = entry.key as? String {
                result[key] = entry.value
            }
        }

        Task {
            await AnalyticsManager.shared.logEvent(eventName: "notification_presented_foreground", parameters: loggableUserInfo)
            print("AnalyticsManager logged 'notification_presented_foreground' (foreground).")
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("ℹ️ Pengguna berinteraksi dengan notifikasi: \(userInfo)")

        Task {
            await AnalyticsManager.shared.logEvent(
                eventName: "ini_custom_notification",
                parameters: [
                    "item_id": "product_123",
                    "item_name": "Awesome T-Shirt",
                    "item_category": "Apparel",
                    "price": 25.99,
                    "quantity": 1
                ]
            )
            print("AnalyticsManager logged 'ini_custom_notification' (notification interaction).")
            completionHandler()
        }
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("✅ FCM registration token: \(String(describing: fcmToken))")
        self.fcmTokenString = fcmToken

        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(name: .didReceiveFCMToken, object: nil, userInfo: dataDict)
    }
}

extension Notification.Name {
    static let didReceiveFCMToken = Notification.Name("didReceiveFCMToken")
}
