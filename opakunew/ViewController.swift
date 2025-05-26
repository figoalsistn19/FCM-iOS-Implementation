//
//  ViewController.swift
//  opakunew
//
//  Created by Jess on 23/05/25.
//
import UIKit
import AmplitudeSwift // Import it here

class MyViewController: UIViewController {

    // Access the Amplitude instance from AppDelegate
    var amplitude: Amplitude {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("AppDelegate not found or Amplitude not initialized.")
        }
        // CORRECTED: Access the 'sharedAmplitude' property
        return appDelegate.sharedAmplitude
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Example: Track a "Screen Viewed" event when the view loads
        amplitude.track(eventType: "Screen Viewed", eventProperties: ["screen_name": "MyViewController"])
        print("Amplitude: 'Screen Viewed' event tracked.")
    }

    // Example: Track a button click
    @IBAction func myButtonTapped(_ sender: UIButton) {
        amplitude.track(eventType: "Button Clicked", eventProperties: ["button_name": "Submit Button"])
        print("Amplitude: 'Button Clicked' event tracked.")
    }

    // Example: Identify a user and set user properties
    func loginUser(userId: String) {
        amplitude.setUserId(userId: userId) // Set the unique user ID

        let identify = Identify()
        identify.set(property: "user_type", value: "premium")
        identify.set(property: "account_created_date", value: Date().ISO8601Format())
        amplitude.identify(identify: identify)
        print("Amplitude: User identified and properties set.")
    }
}
