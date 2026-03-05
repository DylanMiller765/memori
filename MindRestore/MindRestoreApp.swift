import SwiftUI
import SwiftData

@main
struct MindRestoreApp: App {
    @AppStorage("appTheme") private var appTheme: String = AppTheme.system.rawValue

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appTheme) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(selectedTheme.colorScheme)
        }
        .modelContainer(for: [
            User.self,
            Exercise.self,
            SpacedRepetitionCard.self,
            DailySession.self,
        ])
    }
}
