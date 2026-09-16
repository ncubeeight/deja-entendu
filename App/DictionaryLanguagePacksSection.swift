import SwiftUI
import Translation
import Network
import os

/// Lets the user browse Apple's 18 downloadable Translate dictionary
/// languages and pull one down explicitly. Nothing downloads on its own —
/// each pack only starts fetching once the user taps its row, confirms
/// interest, and (if off Wi-Fi) explicitly accepts the cellular-data
/// warning. Downloaded packs let Samples and Vocabulary offer definitions
/// on devices with no on-device model (see SettingsView's device-
/// eligibility interstitial).
///
/// LanguageAvailability.status(from:to:) always reports every pair as
/// .unsupported in the iOS Simulator, even hardcoded pairs with no
/// dependency on this file — confirmed against Apple's own docs/known
/// Simulator limitation, not a bug here. supportedLanguages does return a
/// populated list there, but the actual install/availability backend only
/// works on a physical device, so this screen's status column and
/// download flow need a real device to verify end to end.
struct DictionaryLanguagePacksSection: View {
    @State private var statuses: [SupportedLanguage: LanguageAvailability.Status] = [:]
    @State private var pendingLanguage: SupportedLanguage?
    @State private var configuration: TranslationSession.Configuration?
    @State private var downloadError: SupportedLanguage?
    @State private var languageAwaitingConfirmation: SupportedLanguage?
    @State private var languageAwaitingCellularConfirmation: SupportedLanguage?

    private var sortedLanguages: [SupportedLanguage] {
        SupportedLanguage.translationDictionaryLanguages.sorted { $0.displayName < $1.displayName }
    }

    /// Packs are checked/downloaded as this-language-to-device-language
    /// pairs, matching how Translate itself frames "your languages".
    private var deviceLanguage: Locale.Language {
        Locale.current.language
    }

    /// True when a row's language is (the base language of) the device's
    /// own OS language — e.g. English on an en-US device. Translating a
    /// language to itself isn't a meaningful pair, so status(from:to:)
    /// reads these back as .unsupported even though the definitions are
    /// already there for free as part of the OS. Compared by language
    /// code only (ignoring region/script) so e.g. English matches en-US,
    /// en-GB, en-AU alike.
    private func isDeviceOwnLanguage(_ language: SupportedLanguage) -> Bool {
        language.locale.language.languageCode?.identifier == deviceLanguage.languageCode?.identifier
    }

    var body: some View {
        Section {
            ForEach(sortedLanguages, id: \.self) { language in
                row(for: language)
            }
        } header: {
            Text("Dictionary Language Packs")
        } footer: {
            Text("Download Apple's on-device dictionary for a language so Samples and Vocabulary can still offer definitions on devices without an on-device model. Packs only download when you tap one and confirm, and can be large.")
        }
        .task { await refreshAllStatuses() }
        .translationTask(configuration) { session in
            defer { pendingLanguage = nil }
            do {
                try await session.prepareTranslation()
            } catch {
                downloadError = pendingLanguage
            }
            if let language = pendingLanguage {
                await refreshStatus(for: language)
            }
        }
        // Interest confirmation once Wi-Fi is confirmed present.
        .alert(
            "Download Language Pack?",
            isPresented: Binding(
                get: { languageAwaitingConfirmation != nil },
                set: { if !$0 { languageAwaitingConfirmation = nil } }
            ),
            presenting: languageAwaitingConfirmation
        ) { language in
            Button("Cancel", role: .cancel) {}
            Button("Download") { beginDownload(language) }
        } message: { language in
            Text("Download the \(language.displayName) dictionary pack? Some language packs are quite large.")
        }
        // Shown instead of the above when Wi-Fi isn't detected — requires
        // the explicit "Download Anyway" to proceed on cellular.
        .alert(
            "No Wi-Fi Detected",
            isPresented: Binding(
                get: { languageAwaitingCellularConfirmation != nil },
                set: { if !$0 { languageAwaitingCellularConfirmation = nil } }
            ),
            presenting: languageAwaitingCellularConfirmation
        ) { language in
            Button("Cancel", role: .cancel) {}
            Button("Download Anyway", role: .destructive) { beginDownload(language) }
        } message: { _ in
            Text("Usage and carrier charges from your provider may apply.")
        }
        .alert(
            "Download Failed",
            isPresented: Binding(
                get: { downloadError != nil },
                set: { if !$0 { downloadError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Couldn't download the \(downloadError?.displayName ?? "") language pack. Check your connection and try again.")
        }
    }

    @ViewBuilder
    private func row(for language: SupportedLanguage) -> some View {
        HStack {
            Text(language.displayName)
            Spacer()
            if isDeviceOwnLanguage(language) {
                Text("Default Dictionary")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                switch statuses[language] {
                case .installed:
                    Label("Downloaded", systemImage: "checkmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.green)
                case .unsupported:
                    Text("Unavailable")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .supported, .none:
                    if pendingLanguage == language {
                        ProgressView()
                    } else {
                        Button("Download") {
                            confirmDownload(for: language)
                        }
                        .buttonStyle(.borderless)
                    }
                @unknown default:
                    EmptyView()
                }
            }
        }
    }

    /// Checks Wi-Fi before asking to confirm — a pack is never requested
    /// without the user explicitly agreeing, and off Wi-Fi that agreement
    /// has to be the stronger "Download Anyway" acknowledging cellular
    /// charges rather than the plain confirmation.
    private func confirmDownload(for language: SupportedLanguage) {
        Task {
            if await Self.isOnWiFi() {
                languageAwaitingConfirmation = language
            } else {
                languageAwaitingCellularConfirmation = language
            }
        }
    }

    private func beginDownload(_ language: SupportedLanguage) {
        pendingLanguage = language
        configuration = TranslationSession.Configuration(
            source: language.locale.language,
            target: deviceLanguage
        )
    }

    private func refreshAllStatuses() async {
        let availability = LanguageAvailability()
        for language in sortedLanguages where !isDeviceOwnLanguage(language) {
            statuses[language] = await availability.status(from: language.locale.language, to: deviceLanguage)
        }
    }

    private func refreshStatus(for language: SupportedLanguage) async {
        statuses[language] = await LanguageAvailability().status(from: language.locale.language, to: deviceLanguage)
    }

    /// One-shot check of the active network path — true only when the
    /// currently satisfied connection is actually using the Wi-Fi
    /// interface (not cellular, not a Personal Hotspot over cellular).
    private static func isOnWiFi() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let hasResumed = OSAllocatedUnfairLock(initialState: false)
            monitor.pathUpdateHandler = { path in
                let shouldResume = hasResumed.withLock { resumed in
                    let wasAlreadyResumed = resumed
                    resumed = true
                    return !wasAlreadyResumed
                }
                guard shouldResume else { return }
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied && path.usesInterfaceType(.wifi))
            }
            monitor.start(queue: DispatchQueue.global(qos: .utility))
        }
    }
}
