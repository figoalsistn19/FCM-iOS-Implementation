//
//  Deeplinking.swift
//  opakunew
//
//  Created by Jess on 03/07/25.
//
import UIKit
import Foundation

let deepLinkBaseDomain = "ilmuonedata.com"

class DeepLinkHandler {

    func handleDeepLink(url: URL) async {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        let pathSegments = urlComponents.path.split(separator: "/").map(String.init).filter { !$0.isEmpty }
        let screenPath = pathSegments.last
        
        var parameters: [String: String] = [:]
        urlComponents.queryItems?.forEach { item in
            parameters[item.name] = item.value
        }

        DispatchQueue.main.async {
            self.performNavigation(path: screenPath, parameters: parameters)
        }
    }

    private func performNavigation(path: String?, parameters: [String: String]) {
        // Implement your navigation logic here
    }

    private func resetToRegister() {
        // Implement your logic to reset to the registration screen
    }
}
