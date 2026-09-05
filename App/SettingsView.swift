import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.enabledLanguagesKey) private var enabledLanguagesRaw: String = ""
    @AppStorage(AppSettings.colorSchemeKey) private var colorSchemeRaw: String = AppColorScheme.system.rawValue

    private var enabledLanguages: Set<SupportedLanguage> {
        AppSettings.languages(from: enabledLanguagesRaw)
    }

    var body: some View {
        Form {
            Section {
                ForEach(SupportedLanguage.allCases.sorted { $0.displayName < $1.displayName }, id: \.self) { language in
                    Toggle(language.displayName, isOn: binding(for: language))
                }
            } header: {
                Text("Languages shown on import")
            } footer: {
                Text("Turn off languages you don't use to simplify the picker. At least one must stay on.")
            }

            Section {
                NavigationLink {
                    CustomGlossaryView()
                } label: {
                    Label("Custom Glossary", systemImage: "character.book.closed")
                }
            } footer: {
                Text("Add your own term definitions — useful for specialized vocabulary an on-device model might not know, and still works on devices without one.")
            }

            Section {
                Picker("Appearance", selection: $colorSchemeRaw) {
                    ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                        Text(scheme.displayName).tag(scheme.rawValue)
                    }
                }
            } header: {
                Text("Appearance")
            }

            Section {
                Text(versionLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }

    /// "Version 1.0 Build 25" rather than a single dotted "1.0.25" —
    /// reads straight from the bundle (CFBundleShortVersionString /
    /// CFBundleVersion) so it always matches the running build with no
    /// manual sync needed as the build number increments.
    private var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "—"
        let buildNumber = info?["CFBundleVersion"] as? String ?? "—"
        return "Version \(shortVersion) Build \(buildNumber)"
    }

    private func binding(for language: SupportedLanguage) -> Binding<Bool> {
        Binding(
            get: { enabledLanguages.contains(language) },
            set: { isOn in
                var current = enabledLanguages
                if isOn {
                    current.insert(language)
                } else {
                    current.remove(language)
                }
                // Never let the picker go empty — ignore a toggle-off that
                // would clear the last remaining language.
                guard !current.isEmpty else { return }
                enabledLanguagesRaw = AppSettings.rawValue(from: current)
            }
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
