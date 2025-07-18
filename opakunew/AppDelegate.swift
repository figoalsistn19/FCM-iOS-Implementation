import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import AmplitudeSwift
import FirebaseRemoteConfig
import FirebaseAnalytics
import FirebaseInstallations
import FirebaseFirestore
import FirebaseAuth
import FBSDKCoreKit // <-- Facebook SDK Import

@objcMembers
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    let sharedAmplitude = Amplitude(
        configuration: Configuration(
            apiKey: "YOUR_AMPLITUDE_API_KEY" // Replace with your actual API key
        )
    )
    var fcmTokenString: String?
    var window: UIWindow?
    var remoteConfig: RemoteConfig!
    var deepLinkHandler: DeepLinkHandler!
    var db: Firestore!
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
        // MARK: - Facebook SDK Setup
        // Enable debug logs to see detailed SDK activity in the console.
        Settings.shared.enableLoggingBehavior(.developerErrors)
        
        // Initialize the Facebook SDK.
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        
        // MARK: - Other SDKs Setup
        FirebaseApp.configure()
        db = Firestore.firestore()
        
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
        
        deepLinkHandler = DeepLinkHandler()
        
        return true
    }
    
    // MARK: - Facebook SDK URL Handling
    // Add this function to handle URL redirects (e.g., from Facebook Login).
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        return ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            annotation: options[UIApplication.OpenURLOptionsKey.annotation]
        )
    }
    
    // MARK: - Remote Notifications
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("--- didRegisterForRemoteNotificationsWithDeviceToken callback START ---")
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("✅ APNS device token received: \(tokenString)")
        
        Messaging.messaging().apnsToken = deviceToken
        
        Messaging.messaging().token { token, error in
            print("--- Messaging.messaging().token callback inside didRegisterForRemoteNotificationsWithDeviceToken START ---")
            if let error = error {
                print("❌ Error fetching FCM registration token after APNS token set: \(error.localizedDescription)")
            } else if let token = token {
                self.fcmTokenString = token
                print("✅ Fetched FCM token from Messaging.messaging().token (explicit call): \(token)")
                Task {
                    await self.saveFCMTokenToFirestore(token)
                    await self.savaFCMTokenByLogEvent(token)
                }
            } else {
                print("ℹ️ Messaging.messaging().token callback: Token is nil after APNS set.")
            }
            print("--- Messaging.messaging().token callback inside didRegisterForRemoteNotificationsWithDeviceToken END ---")
        }
        print("--- didRegisterForRemoteNotificationsWithDeviceToken callback END ---")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications with error: \(error.localizedDescription)")
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("--- messaging(_:didReceiveRegistrationToken:) callback START ---")
        print("✅ FCM registration token received via delegate: \(String(describing: fcmToken))")
        self.fcmTokenString = fcmToken
        
        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(name: .didReceiveFCMToken, object: nil, userInfo: dataDict)
        
        if let token = fcmToken {
            Task {
                await savaFCMTokenByLogEvent(token)
                await saveFCMTokenToFirestore(token)
                
                Messaging.messaging().subscribe(toTopic: "promoMay") { error in
                    if let error = error {
                        print("Error subscribing to topic 'promoMay': \(error.localizedDescription)")
                    } else {
                        print("Subscribed to topic 'promoMay' successfully with token: \(token)")
                    }
                }
            }
        } else {
            print("FCM token is nil in didReceiveRegistrationToken, not logging to GA4 or subscribing to topic.")
        }
        print("--- messaging(_:didReceiveRegistrationToken:) callback END ---")
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
        print("ℹ️ Foreground notification received: \(userInfo)")
        
        completionHandler([[.banner, .sound, .badge]])
        
        let loggableUserInfo: [String: Any] = userInfo.reduce(into: [String: Any]()) { result, entry in
            if let key = entry.key as? String {
                result[key] = entry.value
            }
        }
        
        Task {
            await AnalyticsManager.shared.logEvent(eventName: "notification_presented_foreground", parameters: loggableUserInfo)
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("ℹ️ User tapped notification. Response: \(response)")
        
        if let deepLinkURLString = userInfo["deeplinking"] as? String,
           let deepLinkURL = URL(string: deepLinkURLString) {
            print("Attempting to handle deeplink: \(deepLinkURL)")
            Task {
                await self.deepLinkHandler.handleDeepLink(url: deepLinkURL)
                completionHandler()
            }
        } else {
            print("↩️ No 'deeplinking' URL found in notification payload or URL invalid. Opening the app to its default state.")
            completionHandler()
        }
        
        let loggableUserInfo: [String: Any] = userInfo.reduce(into: [String: Any]()) { result, entry in
            if let key = entry.key as? String {
                result[key] = entry.value
            }
        }
        Task {
            await AnalyticsManager.shared.logEvent(eventName: "notification_clicked", parameters: loggableUserInfo)
        }
    }
    
    // MARK: - Firestore & Analytics Helpers
    
    func saveFCMTokenToFirestore(_ token: String) async {
        print("saveFCMTokenToFirestore called with token: \(token)")
        let userID = Auth.auth().currentUser?.uid
        print("Current user ID for Firestore save: \(userID ?? "N/A - user not logged in")")
        
        var tokenData: [String: Any] = [
            "token": token,
            "timestamp": FieldValue.serverTimestamp(),
            "platform": "iOS",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        
        if let userID = userID {
            tokenData["userId"] = userID
        }
        
        let fcmTokensCollectionRef = db.collection("fcm_tokens")
        
        do {
            let querySnapshot = try await fcmTokensCollectionRef
                .whereField("token", isEqualTo: token)
                .getDocuments()
            
            if let existingDoc = querySnapshot.documents.first {
                try await existingDoc.reference.updateData([
                    "timestamp": FieldValue.serverTimestamp(),
                    "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
                ])
                print("✅ Existing FCM token updated in 'fcm_tokens' (ID: \(existingDoc.documentID))")
            } else {
                let documentReference = try await fcmTokensCollectionRef.addDocument(data: tokenData)
                print("✅ New FCM token saved in 'fcm_tokens' with auto-generated ID: \(documentReference.documentID)")
            }
        } catch {
            print("❌ Error saving FCM token to Firestore: \(error.localizedDescription)")
        }
    }
    
    func savaFCMTokenByLogEvent(_ token: String) async {
        var params: [String: Any] = [:]
        let chunkSize = 100
        
        var currentIndex = 0
        var chunkIndex = 0
        while currentIndex < token.count {
            let startIndex = token.index(token.startIndex, offsetBy: currentIndex)
            let endIndex = token.index(startIndex, offsetBy: min(chunkSize, token.count - currentIndex))
            let chunk = String(token[startIndex..<endIndex])
            params["token\(chunkIndex + 1)"] = chunk
            
            currentIndex += chunkSize
            chunkIndex += 1
        }
        
        print("Analytics event parameters for FCM token: \(params)")
        await AnalyticsManager.shared.logEvent(eventName: "fcm_token", parameters: params)
        print("Logged 'fcm_token' event to Analytics.")
    }
}

extension Notification.Name {
    static let didReceiveFCMToken = Notification.Name("didReceiveFCMToken")
}
