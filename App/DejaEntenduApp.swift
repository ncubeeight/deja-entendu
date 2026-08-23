import SwiftUI

@main
struct DejaEntenduApp: App {
    @AppStorage(AppSettings.colorSchemeKey) private var colorSchemeRaw: String = AppColorScheme.system.rawValue

    var body: some Scene {
        WindowGroup {
            VoiceMemoImportView()
                .preferredColorScheme(AppColorScheme(rawValue: colorSchemeRaw)?.colorScheme)
        }
    }
}
