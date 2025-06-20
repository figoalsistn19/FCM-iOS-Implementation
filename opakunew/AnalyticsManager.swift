import Foundation
import FirebaseRemoteConfig
import FirebaseAnalytics
import AmplitudeSwift

class AnalyticsManager {

    static let shared = AnalyticsManager()
    private let sharedAmplitude: Amplitude
    public private(set) var blackListGA4: [String] = []
    private var blacklistLoadingTask: Task<Void, Never>?

    private init() {
        self.sharedAmplitude = Amplitude(configuration: Configuration(apiKey: "YOUR_AMPLITUDE_API_KEY"))
        self.blacklistLoadingTask = Task {
            await loadBlacklist()
        }
    }

    private func loadBlacklist() async {
        var remoteConfigBlockedEvents: [String] = []

        remoteConfigBlockedEvents = await RemoteConfigService.shared.fetchBlockedEvents()
        print("Remote Config blocked events: \(remoteConfigBlockedEvents)")

        var combinedBlacklist = Set<String>()
        combinedBlacklist.formUnion(remoteConfigBlockedEvents)

        self.blackListGA4 = Array(combinedBlacklist)
        print("Final GA4 blacklist: \(blackListGA4)")
    }

    func logEvent(eventName: String, parameters: [String: Any]) async {
        await blacklistLoadingTask?.value

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

class RemoteConfigService {

    static let shared = RemoteConfigService()

    private init() {
    }

    func fetchBlockedEvents() async -> [String] {
        let remoteConfig = RemoteConfig.remoteConfig()
        var blockedEvents: [String] = []

        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RemoteConfigFetchAndActivateStatus, Error>) in
                remoteConfig.fetchAndActivate { (status, error) in
                    if let error = error {
                        print("Error fetching Remote Config: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else if status == .successFetchedFromRemote || status == .successUsingPreFetchedData {
                        print("Remote Config fetched and activated successfully. Status: \(status.rawValue)")
                        continuation.resume(returning: status)
                    } else {
                        print("Remote Config fetch and activate status: \(status.rawValue)")
                        continuation.resume(returning: status)
                    }
                }
            }

            let blockedEventsString = remoteConfig.configValue(forKey: "firebase_blocked_events").stringValue ?? ""
            blockedEvents = blockedEventsString
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

        } catch {
            print("An error occurred during Remote Config fetch (or its activation): \(error.localizedDescription)")
            blockedEvents = []
        }
        return blockedEvents
    }
}
