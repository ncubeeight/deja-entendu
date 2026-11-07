import SwiftUI
import FoundationModels

struct SettingsView: View {
    @AppStorage(AppSettings.colorSchemeKey) private var colorSchemeRaw: String = AppColorScheme.system.rawValue
    @AppStorage(AppSettings.speechPaceKey) private var speechPaceRaw: String = SpeechPace.normal.rawValue
    @State private var languageSearchText = ""
    @State private var previewSpeaker = TextSpeaker()
    @State private var isConnectDictionaryPresented = false
    @State private var connectedDictionaries: [ConnectedDictionary] = ConnectedDictionaryStore.load()

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
                Picker("Speech Speed", selection: $speechPaceRaw) {
                    ForEach(SpeechPace.allCases, id: \.self) { pace in
                        Text(pace.displayName).tag(pace.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    previewSpeaker.speak("This is how fast words will be read aloud.", language: .english)
                } label: {
                    Label("Preview", systemImage: "speaker.wave.2.fill")
                }
            } header: {
                Text("Speech Speed")
            } footer: {
                Text("Applies everywhere text is read aloud — Samples transcripts, word pronunciations, and Vocabulary flashcards. You can also change it from the speed icon next to any speak button.")
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
                    if !connectedDictionaries.isEmpty {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Connect Local Dictionary")
                                Text(connectedDictionaries.map(\.language.displayName).joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
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

            LanguageTogglesSection(searchText: languageSearchText, connectedDictionaries: connectedDictionaries)

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
        .onAppear {
            connectedDictionaries = ConnectedDictionaryStore.load()
        }
        .onDisappear { previewSpeaker.stop() }
        .sheet(isPresented: $isConnectDictionaryPresented, onDismiss: {
            connectedDictionaries = ConnectedDictionaryStore.load()
        }) {
            ConnectLocalDictionaryView()
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
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

// MARK: - Language toggles (shared with the Samples language pickers)

/// The "Languages shown on import" toggle list. Lives here, but is also
/// reachable from every Samples language picker via ManageLanguagesLink —
/// new users don't always think to look in Settings to trim or extend the
/// list they're picking from.
struct LanguageTogglesSection: View {
    let searchText: String
    let connectedDictionaries: [ConnectedDictionary]

    @AppStorage(AppSettings.enabledLanguagesKey) private var enabledLanguagesRaw: String = ""
    @State private var dictionaryPackInterstitialLanguage: SupportedLanguage?

    private var enabledLanguages: Set<SupportedLanguage> {
        AppSettings.languages(from: enabledLanguagesRaw)
    }

    private var filteredLanguages: [SupportedLanguage] {
        let sorted = SupportedLanguage.allCases.sorted { $0.displayName < $1.displayName }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Section {
            if filteredLanguages.isEmpty {
                Text("No languages match \"\(searchText)\".")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredLanguages, id: \.self) { language in
                    Toggle(isOn: binding(for: language)) {
                        if connectedDictionaries.contains(where: { $0.language == language }) {
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
            Text("Turn off languages you don't use to simplify the picker. At least one must stay on. A language added by connecting a dictionary appears here too — turning it off hides it from the picker and pauses that dictionary's definitions without disconnecting it.")
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
                   language.hasDictionaryPack,
                   case .unavailable(.deviceNotEligible) = SystemLanguageModel.default.availability {
                    dictionaryPackInterstitialLanguage = language
                }
            }
        )
    }
}

/// The toggle list on its own screen, pushed from a Samples language
/// picker. Changes write straight to the same @AppStorage key, so the
/// picker underneath updates as soon as the user goes back.
struct ManageLanguagesView: View {
    @State private var searchText = ""
    @State private var connectedDictionaries: [ConnectedDictionary] = ConnectedDictionaryStore.load()

    var body: some View {
        Form {
            LanguageTogglesSection(searchText: searchText, connectedDictionaries: connectedDictionaries)
        }
        .navigationTitle("Languages")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Languages")
    }
}

/// "Add or Remove Languages" call-to-action placed under each Samples
/// language picker. Needs to sit inside a NavigationStack (every picker
/// sheet already has one).
struct ManageLanguagesLink: View {
    var body: some View {
        NavigationLink {
            ManageLanguagesView()
        } label: {
            Label("Add or Remove Languages", systemImage: "globe")
        }
    }
}

/// The same call-to-action pinned under a language list — used by the
/// Samples "Choose Language" sheets, whose inline lists run past the fold
/// at the sheet's half-height detent, where an in-list row would go unseen.
struct ManageLanguagesBar: View {
    var body: some View {
        NavigationLink {
            ManageLanguagesView()
        } label: {
            Label("Add or Remove Languages", systemImage: "globe")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
