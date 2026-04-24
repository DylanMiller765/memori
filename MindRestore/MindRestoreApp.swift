import SwiftUI
import SwiftData
import UIKit
import UserNotifications

@main
struct MindRestoreApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("appTheme") private var appTheme: String = AppTheme.light.rawValue

    init() {
        Analytics.configure()
        configureTabBarAppearance()
    }

    private func configureTabBarAppearance() {
        // Force non-translucent tab bar to avoid iOS 26 Liquid Glass black icons
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground

        let gray = UIColor(white: 0.55, alpha: 1.0)
        appearance.stackedLayoutAppearance.normal.iconColor = gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: gray]
        appearance.inlineLayoutAppearance.normal.iconColor = gray
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: gray]
        appearance.compactInlineLayoutAppearance.normal.iconColor = gray
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: gray]

        let accent = UIColor(AppColors.accent)
        appearance.stackedLayoutAppearance.selected.iconColor = accent
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]
        appearance.inlineLayoutAppearance.selected.iconColor = accent
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]
        appearance.compactInlineLayoutAppearance.selected.iconColor = accent
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private var colorScheme: ColorScheme? {
        AppTheme(rawValue: appTheme)?.colorScheme
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
        }
        .modelContainer(
            try! ModelContainer(
                for: User.self, Exercise.self, SpacedRepetitionCard.self,
                     DailySession.self, BrainScoreResult.self, Achievement.self,
                configurations: ModelConfiguration(cloudKitDatabase: .none)
            )
        )
    }
}

// MARK: - AppDelegate (notification handling)

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Handle notification tap — convert deep link in userInfo to URL open
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let deepLink = userInfo["deepLink"] as? String,
           let url = URL(string: deepLink) {
            let notificationType = response.notification.request.content.categoryIdentifier.isEmpty
                ? response.notification.request.identifier.components(separatedBy: "_").first ?? "unknown"
                : response.notification.request.content.categoryIdentifier
            Analytics.appOpenedFromNotification(notificationType: notificationType)
            UIApplication.shared.open(url)
        }
        completionHandler()
    }

    /// Show notification even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
