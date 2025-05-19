//
//  AppDelegate.swift
//  opaku
//
//  Created by Figo Alsistani on 09/05/25.
//
import UIKit
import FirebaseCore
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
        
        return true
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

