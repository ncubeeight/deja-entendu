import SwiftUI
import FoundationModels

struct SettingsView: View {
    @AppStorage(AppSettings.enabledLanguagesKey) private var enabledLanguagesRaw: String = ""
    @AppStorage(AppSettings.colorSchemeKey) private var colorSchemeRaw: String = AppColorScheme.system.rawValue
    @State private var languageSearchText = ""
    @State private var dictionaryPackInterstitialLanguage: SupportedLanguage?
    @State private var isConnectDictionaryPresented = false
    @State private var connectedDictionary: ConnectedDictionary? = ConnectedDictionaryStore.load()

    private var enabledLanguages: Set<SupportedLanguage> {
        AppSettings.languages(from: enabledLanguagesRaw)
    }

    private var filteredLanguages: [SupportedLanguage] {
        let sorted = SupportedLanguage.allCases.sorted { $0.displayName < $1.displayName }
        guard !languageSearchText.isEmpty else { return sorted }
        return sorted.filter { $0.displayName.localizedCaseInsensitiveContains(languageSearchText) }
    }

    var body: some View {
        Form {
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
                NavigationLink {
                    CustomGlossaryView()
                } label: {
                    Label("Custom Glossary", systemImage: "character.book.closed")
                }

                Button {
                    isConnectDictionaryPresented = true
                } label: {
                    if let connectedDictionary {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Connect Local Dictionary")
                                Text("\(connectedDictionary.fileName) · \(connectedDictionary.language.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    } else {
                        Label("Connect Local Dictionary", systemImage: "folder.badge.plus")
                    }
                }
            } footer: {
                Text("Add your own term definitions — useful for specialized vocabulary an on-device model might not know, and still works on devices without one. Connect a dictionary file from Files to bulk-import its terms instead of typing them in one at a time.")
            }

            Section {
                if filteredLanguages.isEmpty {
                    Text("No languages match \"\(languageSearchText)\".")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredLanguages, id: \.self) { language in
                        Toggle(isOn: binding(for: language)) {
                            if connectedDictionary?.language == language {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(language.displayName)
                                    Text("Connected dictionary")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text(language.displayName)
                            }
                        }
                    }
                }
            } header: {
                Text("Languages shown on import")
            } footer: {
                Text("Turn off languages you don't use to simplify the picker. At least one must stay on.")
            }

            DictionaryLanguagePacksSection()

            Section {
                Text(versionLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $languageSearchText, prompt: "Search Languages")
        .sheet(isPresented: $isConnectDictionaryPresented, onDismiss: {
            connectedDictionary = ConnectedDictionaryStore.load()
        }) {
            ConnectLocalDictionaryView()
        }
        .alert(
            "No On-Device Model",
            isPresented: Binding(
                get: { dictionaryPackInterstitialLanguage != nil },
                set: { if !$0 { dictionaryPackInterstitialLanguage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please import the language pack for this language when phone has wi-fi coverage.")
        }
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

                // On a device that can't run the on-device model at all
                // (not just "not enabled yet" or "still downloading"),
                // Samples/Vocabulary definitions for this language will
                // need Apple's offline dictionary pack instead — point the
                // user at it rather than let lookups silently fail later.
                if isOn,
                   SupportedLanguage.translationDictionaryLanguages.contains(language),
                   case .unavailable(.deviceNotEligible) = SystemLanguageModel.default.availability {
                    dictionaryPackInterstitialLanguage = language
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
