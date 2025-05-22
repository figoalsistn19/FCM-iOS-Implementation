import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    // Properti untuk menyimpan token (opsional, bisa juga dikelola di NotificationService)
    var fcmTokenString: String?
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Konfigurasi Firebase
        FirebaseApp.configure()

        // Set delegate untuk UserNotifications
        UNUserNotificationCenter.current().delegate = self

        // Set delegate untuk Firebase Messaging
        Messaging.messaging().delegate = self
        Messaging.messaging().subscribe(toTopic: "promoMay")
//        Analytics.logEvent("item_purchased", parameters: [
//              "item_id": "product_123",
//              "item_name": "Awesome T-Shirt",
//              "item_category": "Apparel",
//              "price": 25.99 as NSObject, // Values need to be of type NSObject
//              "quantity": 1 as NSObject
//            ])
        return true
    }
    
    func application(_ application: UIApplication,
                         didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                         fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
            
            print("Notifikasi remote diterima (mungkin di background): \(userInfo)")

            // --- LOG CUSTOM EVENT ANALYTICS ---
            // Cek apakah ini bukan duplikat dari `userNotificationCenter` jika notifikasi juga visible
            // Misalnya, jika Anda HANYA ingin log silent push di sini
            let isSilentPush = (userInfo["aps"] as? [String: AnyObject])?["content-available"] as? Int == 1
            
            // Anda bisa menambahkan logika untuk hanya log jika ini adalah silent push,
            // atau jika Anda ingin melacak semua penerimaan data di background.
            // Untuk contoh ini, kita log setiap kali metode ini dipanggil.
            
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
            
            Analytics.logEvent("notification_processed", parameters: eventParams)
            print("Analytics event 'notification_processed' (background data) logged.")
            
            completionHandler(.newData) // atau .noData / .failed
        }

    // MARK: - UNUserNotificationCenterDelegate (Untuk notifikasi foreground)
    // Dipanggil ketika notifikasi diterima saat aplikasi berada di foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("ℹ️ Notifikasi diterima di foreground: \(userInfo)")

        // Tampilkan notifikasi (banner, sound, badge)
        // Jika menggunakan iOS 14+, bisa menggunakan .list dan .banner
        completionHandler([[.alert, .sound, .badge]])
        
    }

    // Dipanggil ketika pengguna berinteraksi dengan notifikasi (misalnya, tap)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("ℹ️ Pengguna berinteraksi dengan notifikasi: \(userInfo)")
        // Tambahkan logic untuk menangani aksi notifikasi di sini
        
        Analytics.logEvent("ini_custom_notification", parameters: [
              "item_id": "product_123",
              "item_name": "Awesome T-Shirt",
              "item_category": "Apparel",
              "price": 25.99 as NSObject, // Values need to be of type NSObject
              "quantity": 1 as NSObject
            ])

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
