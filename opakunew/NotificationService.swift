//
//  NotificationService.swift
//  opaku
//
//  Created by Figo Alsistani on 09/05/25.
//
import SwiftUI
import UserNotifications
import FirebaseMessaging


class NotificationService: ObservableObject {
    @Published var fcmToken: String = "Belum ada FCM Token"
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    init() {
        // Dengarkan notifikasi dari AppDelegate
//        Messaging.messaging().subscribe(toTopic: "promoMay")
        NotificationCenter.default.addObserver(self, selector: #selector(updateFCMToken(_:)), name: .didReceiveFCMToken, object: nil)
        // Periksa status otorisasi saat ini
        checkNotificationAuthorizationStatus()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    
    @objc private func updateFCMToken(_ notification: Notification) {
        if let token = notification.userInfo?["token"] as? String {
            DispatchQueue.main.async {
                self.fcmToken = token
                self.errorMessage = nil
            }
        }
    }


    func checkNotificationAuthorizationStatus() {
        Messaging.messaging().subscribe(toTopic: "promoMay")
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                print("ℹ️ Status izin notifikasi saat ini: \(settings.authorizationStatus.rawValue)")
                // Jika sudah diizinkan, coba daftarkan remote notification lagi
                // (FCM SDK mungkin akan mengambilnya jika sudah pernah gagal karena izin)
                if settings.authorizationStatus == .authorized {
                     self.registerForRemoteNotifications()
                }
            }
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🛑 Error meminta izin notifikasi: \(error.localizedDescription)")
                    self.errorMessage = "Error izin: \(error.localizedDescription)"
                    self.authorizationStatus = .denied // atau .notDetermined jika error bukan karena penolakan
                    return
                }

                if granted {
                    print("✅ Izin notifikasi diberikan.")
                    self.authorizationStatus = .authorized
                    self.registerForRemoteNotifications()
                } else {
                    print("❌ Izin notifikasi ditolak.")
                    self.authorizationStatus = .denied
                    self.errorMessage = "Izin notifikasi ditolak oleh pengguna."
                }
            }
        }
    }

    private func registerForRemoteNotifications() {
        // Pastikan ini dipanggil di main thread
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
            print("ℹ️ Memulai pendaftaran untuk remote notifications...")
        }
    }
}
