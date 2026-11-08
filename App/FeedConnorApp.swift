import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    static var configured = false
    static func configureFirebase() {
        guard !ScreenshotFixtures.active else { return }
        guard FirebaseApp.app() == nil else { configured = true; return }
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist", inDirectory: "Firebase"),
              let options = FirebaseOptions(contentsOfFile: path) else { return }
        FirebaseApp.configure(options: options)
        configured = true
    }
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Self.configureFirebase()
        guard Self.configured else { return true }
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        NotificationCenter.default.post(name: .messagingTokenChanged, object: nil)
    }
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        NotificationCenter.default.post(name: .messagingTokenChanged, object: nil)
    }
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Task { @MainActor in
            let refreshed = await BackgroundSync.refresh()
            completionHandler(refreshed ? .newData : .noData)
        }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound] }
}
@main
struct FeedConnorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    init() { AppDelegate.configureFirebase() }
    var body: some Scene {
        WindowGroup {
            Group {
                if ScreenshotFixtures.active || AppDelegate.configured { ConnectedRoot() }
                else {
                    VStack(spacing: 24) {
                        Text("FEED CONNOR")
                        Text("Firebase configuration required. Follow docs/DEPLOYMENT.md and add GoogleService-Info.plist to build this app.")
                    }.padding(32)
                }
            }
            .font(Minimal.font()).foregroundStyle(.black).tint(.black)
            .preferredColorScheme(.light)
        }
    }
}
