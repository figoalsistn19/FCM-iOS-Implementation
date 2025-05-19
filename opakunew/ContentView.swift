//
//  ContentView.swift
//  opaku
//
//  Created by Figo Alsistani on 28/04/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var notificationService = NotificationService()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Notification Management")
                    .font(.headline)

                // button to request notification permission
                if notificationService.authorizationStatus == .notDetermined {
                    Button("Request Notification Request") {
                        notificationService.requestNotificationPermission()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                } else if notificationService.authorizationStatus == .denied {
                    Text("Permission Declined. Turn on in settings.")
                        .foregroundColor(.red)
                    Button("Open settings") {
                        if let appSettings = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(appSettings) {
                            UIApplication.shared.open(appSettings)
                        }
                    }
                } else if notificationService.authorizationStatus == .authorized {
                    Text("Notification: Granted 👍")
                        .foregroundColor(.green)
                } else {
                     Text("Permission Status: \(notificationService.authorizationStatus.rawValue)") // other status if exist
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("FCM Token:")
                        .font(.caption)
                        .padding(.top)
                    Text(notificationService.fcmToken)
                        .font(.footnote)
                        .lineLimit(nil)
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = notificationService.fcmToken
                            }) {
                                Text("Copy FCM Token")
                                Image(systemName: "doc.on.doc")
                            }
                        }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)


                if let errorMessage = notificationService.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding(.top)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Notification & Token")
            .onAppear {
                // Check status when view showed, if needed
                // notificationService.checkNotificationAuthorizationStatus()
            }
        }
    }
}

// Untuk preview, jika diperlukan
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

//#Preview {
//    ContentView()
//        .modelContainer(for: Item.self, inMemory: true)
//}
