import Foundation
import FirebaseAnalytics
import AmplitudeSwift

class AnalyticsManager {

    static let shared = AnalyticsManager()

    private let sharedAmplitude: Amplitude

    // Define your GA4 blacklist. Add any event names you do NOT want sent to Firebase.
    private let blackListGA4: [String] = ["purchase", "some_other_event_to_exclude", "another_event"]

    private init() {
        self.sharedAmplitude = Amplitude(configuration: Configuration(apiKey: "YOUR_AMPLITUDE_API_KEY"))
//        self.sharedAmplitude.debugMode = true
    }

    func logEvent(eventName: String, parameters: [String: Any]) {

        // --- Log to Firebase Analytics ---
        // Check if the eventName is in the GA4 blacklist
        if !blackListGA4.contains(eventName) {
            var firebaseParams: [String: Any] = [:]
            for (key, value) in parameters {
                if let doubleValue = value as? Double {
                    firebaseParams[key] = doubleValue as NSObject
                } else if let intValue = value as? Int {
                    firebaseParams[key] = intValue as NSObject
                } else {
                    firebaseParams[key] = value
                }
            }
            Analytics.logEvent(eventName, parameters: firebaseParams)
            print("Logged to Firebase Analytics: \(eventName) with parameters: \(firebaseParams)")
        } else {
            print("Firebase Analytics logging skipped for blacklisted event: \(eventName)")
        }

        // --- Log to Amplitude-Swift ---
        // Amplitude logging is not affected by the GA4 blacklist in this setup
        self.sharedAmplitude.track(eventType: eventName, eventProperties: parameters)
        print("Logged to Amplitude-Swift: \(eventName) with properties: \(parameters)")
    }
}
