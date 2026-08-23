import SwiftUI

@main
struct DejaEntenduApp: App {
    @AppStorage(AppSettings.colorSchemeKey) private var colorSchemeRaw: String = AppColorScheme.system.rawValue

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(AppColorScheme(rawValue: colorSchemeRaw)?.colorScheme)
        }
    }
}
