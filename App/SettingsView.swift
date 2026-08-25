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
                Picker("Appearance", selection: $colorSchemeRaw) {
                    ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                        Text(scheme.displayName).tag(scheme.rawValue)
                    }
                }
            } header: {
                Text("Appearance")
            }
        }
        .navigationTitle("Settings")
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
