import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications
import AmplitudeSwift // Make sure you import the correct module

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    // Make the amplitude instance accessible globally.
    // This needs to be a stored property of the class, not directly in the class body like a function.
    let sharedAmplitude = Amplitude(
        configuration: Configuration(
            apiKey: "YOUR_AMPLITUDE_API_KEY" // Replace with your actual API Key
        )
    )

    // Properti untuk menyimpan token (opsional, bisa juga dikelola di NotificationService)
    var fcmTokenString: String?
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Konfigurasi Firebase
        FirebaseApp.configure()

        // Set delegate untuk UserNotifications
        UNUserNotificationCenter.current().delegate = self

        // Set delegate untuk Firebase Messaging
        Messaging.messaging().delegate = self
        Messaging.messaging().subscribe(toTopic: "promoMay")

        // Firebase Analytics event (leave this if you still want to use Firebase Analytics)
        Analytics.logEvent("item_purchased", parameters: [
            "item_id": "product_123",
            "item_name": "Awesome T-Shirt",
            "item_category": "Apparel",
            "price": 25.99 as NSObject,
            "quantity": 1 as NSObject
        ])

        self.sharedAmplitude.track(
            eventType: "item_purchased",
            eventProperties: [
                "item_id": "product_123",
                "item_name": "Awesome T-Shirt",
                "item_category": "Apparel",
                "price": 25.99,
                "quantity": 1
            ]
        )
        return true
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        print("Notifikasi remote diterima (mungkin di background): \(userInfo)")

        // --- LOG CUSTOM EVENT ANALYTICS ---
        let isSilentPush = (userInfo["aps"] as? [String: AnyObject])?["content-available"] as? Int == 1

        var eventParams: [String: Any] = [
            "trigger_point": "background_data_receive",
            "is_silent_push": isSilentPush,
            AnalyticsParameterContentType: "notification"
        ]
        if let notificationId = userInfo["gcm.message_id"] as? String {
            eventParams["notification_id"] = notificationId
        }
        if let customData = userInfo["custom_key"] as? String {
            eventParams["custom_payload_data"] = customData
        }

        // Firebase Analytics event
        Analytics.logEvent("notification_processed", parameters: eventParams)
        print("Firebase Analytics event 'notification_processed' (background data) logged.")

        // Amplitude event log for notification processing
        self.sharedAmplitude.track(
            eventType: "notification_processed",
            eventProperties: eventParams // Reusing the same parameters
        )
        print("Amplitude event 'notification_processed' (background data) logged.")

        completionHandler(.newData)
    }

    // MARK: - UNUserNotificationCenterDelegate (Untuk notifikasi foreground)
    // Dipanggil ketika notifikasi diterima saat aplikasi berada di foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("ℹ️ Notifikasi diterima di foreground: \(userInfo)")

        // Tampilkan notifikasi (banner, sound, badge)
        completionHandler([[.alert, .sound, .badge]])

    }

    // Dipanggil ketika pengguna berinteraksi dengan notifikasi (misalnya, tap)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("ℹ️ Pengguna berinteraksi dengan notifikasi: \(userInfo)")
        // Tambahkan logic untuk menangani aksi notifikasi di sini

        // Firebase Analytics event for notification interaction
        Analytics.logEvent("ini_custom_notification", parameters: [
            "item_id": "product_123",
            "item_name": "Awesome T-Shirt",
            "item_category": "Apparel",
            "price": 25.99 as NSObject,
            "quantity": 1 as NSObject
        ])
        print("Firebase Analytics event 'ini_custom_notification' (notification interaction) logged.")


        // Amplitude event log for notification interaction
        self.sharedAmplitude.track(
            eventType: "ini_custom_notification",
            eventProperties: [
                "item_id": "product_123",
                "item_name": "Awesome T-Shirt",
                "item_category": "Apparel",
                "price": 25.99,
                "quantity": 1
            ]
        )
        print("Amplitude event 'ini_custom_notification' (notification interaction) logged.")

        completionHandler()
    }

    // MARK: - Firebase Messaging Delegate
    // Dipanggil ketika FCM registration token baru diterima atau diperbarui
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("✅ FCM registration token: \(String(describing: fcmToken))")
        self.fcmTokenString = fcmToken

        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(name: .didReceiveFCMToken, object: nil, userInfo: dataDict)

        // TODO: Jika Anda ingin mengirim token ini ke server aplikasi Anda, lakukan di sini.
        // Contoh: self.sendFcmTokenToServer(fcmToken)
    }
}

// Tambahkan ekstensi untuk nama Notifikasi kustom
extension Notification.Name {
    static let didReceiveFCMToken = Notification.Name("didReceiveFCMToken")
}
