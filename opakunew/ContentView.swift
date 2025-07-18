import SwiftUI
import SwiftData
import FBSDKCoreKit
import AppTrackingTransparency

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
                Button("Request Tracking Permission") {
                    requestTrackingPermission()
                }
                .padding()
                .background(Color.orange) // Warna berbeda agar mudah dikenali
                .foregroundColor(.white)
                .cornerRadius(8)
                // Tombol untuk navigasi ke ProductListView
                NavigationLink(destination: ProductListView()) {
                    Text("Lihat Daftar Produk")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                }

                if let errorMessage = notificationService.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding(.top)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Home Screen")
            .onAppear {
                requestTrackingPermission()
                
                let eventName = "page"
                let parameters: [AppEvents.ParameterName: Any] = [
                    AppEvents.ParameterName("name"): "home screen"
                ]
                AppEvents.shared.logEvent(AppEvents.Name(eventName), parameters: parameters)
                print("✅ DEBUG: Event '\(eventName)' dengan parameter \(parameters) telah dikirim ke Meta.")
            }
        }
    }

    // FUNGSI INI SEKARANG BERADA DI DALAM STRUCT
    func requestTrackingPermission() {
        // Beri jeda 1 detik untuk menghindari konflik dengan permintaan izin lain
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    Settings.shared.isAdvertiserIDCollectionEnabled = true
                    print("✅ ATT: Authorized")
                case .denied:
                    print("❌ ATT: Denied")
                case .notDetermined:
                    print("🤔 ATT: Not Determined")
                case .restricted:
                    print("🚫 ATT: Restricted")
                @unknown default:
                    print("🤷 ATT: Unknown")
                }
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
