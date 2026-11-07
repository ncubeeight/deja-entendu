import SwiftUI

@main
struct DejaEntenduApp: App {
    @AppStorage(AppSettings.colorSchemeKey) private var colorSchemeRaw: String = AppColorScheme.system.rawValue

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(AppColorScheme(rawValue: colorSchemeRaw)?.colorScheme)
                .task {
                    // Pick up any languages Apple has added support for
                    // since last launch. Off the main actor: the Vision
                    // query is synchronous.
                    await Task.detached(priority: .utility) {
                        await LanguageDiscovery.refresh()
                    }.value
                }
        }
    }
}
