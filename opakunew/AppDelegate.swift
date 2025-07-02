import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import AmplitudeSwift
import FirebaseRemoteConfig
import FirebaseAnalytics // Make sure this is imported
import FirebaseInstallations

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

        Installations.installations().installationID { (id, error) in
            if let error = error {
                print("Error getting installation ID: \(error.localizedDescription)")
                return
            }
            if let id = id {
                print("Instance ID for testing: \(id)")
            }
        }

        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if let error = error {
                    print("Error requesting APNS authorization: \(error.localizedDescription)")
                }
                guard granted else {
                    print("User denied notification permissions.")
                    return
                }
                print("User granted notification permissions.")
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        )

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("✅ APNS device token received: \(tokenString)")
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications with error: \(error.localizedDescription)")
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        print("Notifikasi remote diterima (mungkin di background): \(userInfo)")

        let isSilentPush = (userInfo["aps"] as? [String: AnyObject])?["content-available"] as? Int == 1

        var eventParams: [String: Any] = userInfo.reduce(into: [String: Any]()) { result, entry in
            if let key = entry.key as? String {
                result[key] = entry.value
            }
        }

        eventParams["trigger_point"] = "background_data_receive"
        eventParams["is_silent_push"] = isSilentPush
        eventParams[AnalyticsParameterContentType] = "notification"

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

    // Modified method to send FCM token to GA4
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("✅ FCM registration token: \(String(describing: fcmToken))")
        self.fcmTokenString = fcmToken

        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(name: .didReceiveFCMToken, object: nil, userInfo: dataDict)

        // Log FCM token to GA4
        if let token = fcmToken {
            var params: [String: Any] = [:]
            let chunkSize = 100 // Maximum characters per parameter

            // Split the token into chunks
            var currentIndex = 0
            var chunkIndex = 0
            while currentIndex < token.count {
                let startIndex = token.index(token.startIndex, offsetBy: currentIndex)
                let endIndex = token.index(startIndex, offsetBy: min(chunkSize, token.count - currentIndex))
                let chunk = String(token[startIndex..<endIndex])
                params["token\(chunkIndex+1)"] = chunk

                currentIndex += chunkSize
                chunkIndex += 1
            }
            
            print("PARAMM: ", params)

            // You'll need to use your AnalyticsManager to log this event
            Task {
                await AnalyticsManager.shared.logEvent(eventName: "fcm_token", parameters: params)
                print("AnalyticsManager logged 'token_receive' event to GA4 with token chunks.")
            }

            // Subscribe to topic here
            Messaging.messaging().subscribe(toTopic: "promoMay") { error in
                if let error = error {
                    print("Error subscribing to topic 'promoMay': \(error.localizedDescription)")
                } else {
                    print("Subscribed to topic 'promoMay' successfully with token: \(token)")
                }
            }
        } else {
            print("FCM token is nil, not logging to GA4 or subscribing to topic.")
        }
    }
}

extension Notification.Name {
    static let didReceiveFCMToken = Notification.Name("didReceiveFCMToken")
}
