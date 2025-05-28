import Foundation
import FirebaseAnalytics
import AmplitudeSwift
import FirebaseFirestore

class AnalyticsManager {

    static let shared = AnalyticsManager()
    private let sharedAmplitude: Amplitude
    public private(set) var blackListGA4: [String] = []

    private init() {
        self.sharedAmplitude = Amplitude(configuration: Configuration(apiKey: "YOUR_AMPLITUDE_API_KEY"))
        Task {
            await loadBlacklist()
        }
    }

    private func loadBlacklist() async {
        do {
            self.blackListGA4 = try await fetchBlockedEvent()
            print("the event", blackListGA4)
        } catch {
            self.blackListGA4 = []
        }
    }

    func logEvent(eventName: String, parameters: [String: Any]) {
        if !blackListGA4.contains(eventName) {
            print("The event '\(eventName)' will be pushed to GA4")
            var firebaseParams: [String: Any] = [:]
            for (key, value) in parameters {
                if let doubleValue = value as? Double {
                    firebaseParams[key] = doubleValue as NSObject
                } else if let intValue = value as? Int {
                    firebaseParams[key] = intValue as NSObject
                } else if let boolValue = value as? Bool {
                    firebaseParams[key] = boolValue as NSObject
                } else if let stringValue = value as? String {
                    firebaseParams[key] = stringValue as NSObject
                } else if let urlValue = value as? URL {
                    firebaseParams[key] = urlValue.absoluteString as NSObject
                } else {
                    firebaseParams[key] = value
                }
            }
            Analytics.logEvent(eventName, parameters: firebaseParams)
        } else {
            print("The event '\(eventName)' is on the GA4 blacklist and will NOT be pushed to GA4.")
        }

        self.sharedAmplitude.track(eventType: eventName, eventProperties: parameters)
        print("The event '\(eventName)' will be pushed to Amplitude")
    }
}

func fetchBlockedEvent() async throws -> [String] {
    let db = Firestore.firestore()
    let documentID = "blockedEvent"
    let fieldName = "eventName"
    let documentRef = db.collection("BlockedEvents").document(documentID)

    do {
        let documentSnapshot = try await documentRef.getDocument()

        guard documentSnapshot.exists else {
            return []
        }

        if let data = documentSnapshot.data(),
           let eventNamesArray = data[fieldName] as? [String] {
            return eventNamesArray
        } else {
            return []
        }
    } catch {
        throw error
    }
}
