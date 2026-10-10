import SwiftUI

/// Terms shared in from other apps (e.g. Translate) via the Share
/// Extension's plain-text path, plus anything added manually later.
struct VocabularyListView: View {
    @State private var entries: [VocabularyEntry] = VocabularyStore.load()
    @State private var pendingSharedTexts: [String] = []
    @State private var isLanguageSheetPresented = false
    @State private var pendingLanguage: SupportedLanguage = .chineseTraditional
    @State private var sortOption: VocabularySort = .dateNewestFirst

    @AppStorage(AppSettings.enabledLanguagesKey) private var enabledLanguagesRaw: String = ""

    private var enabledLanguages: [SupportedLanguage] {
        let enabled = AppSettings.languages(from: enabledLanguagesRaw)
        return SupportedLanguage.allCases.filter { enabled.contains($0) }
    }

    /// One term per line, in whatever order is currently on screen, with
    /// its translation/language alongside when known.
    private var shareText: String {
        let lines = entries.map { entry -> String in
            let subtitle = [entry.translation, entry.language?.displayName].compactMap { $0 }.joined(separator: " · ")
            return subtitle.isEmpty ? entry.text : "\(entry.text) — \(subtitle)"
        }
        return (lines + ["", "Shared from Déjà Entendu on iOS"]).joined(separator: "\n")
    }

    /// Mirrors Samples' sort menu. entries is kept sorted in place (rather
    /// than sorting a copy just for display) so .onDelete's IndexSet —
    /// which indexes into entries — always matches what's on screen.
    private enum VocabularySort: String, CaseIterable, Identifiable {
        case dateNewestFirst, dateOldestFirst, language, title

        var id: String { rawValue }

        var label: String {
            switch self {
            case .dateNewestFirst: "Date (Newest First)"
            case .dateOldestFirst: "Date (Oldest First)"
            case .language: "Language"
            case .title: "Title"
            }
        }

        var icon: String {
            switch self {
            case .dateNewestFirst: "arrow.down"
            case .dateOldestFirst: "arrow.up"
            case .language: "globe"
            case .title: "textformat"
            }
        }

        func sort(_ entries: [VocabularyEntry]) -> [VocabularyEntry] {
            switch self {
            case .dateNewestFirst:
                entries.sorted { $0.addedAt > $1.addedAt }
            case .dateOldestFirst:
                entries.sorted { $0.addedAt < $1.addedAt }
            case .language:
                entries.sorted {
                    ($0.language?.displayName ?? "").localizedCaseInsensitiveCompare($1.language?.displayName ?? "") == .orderedAscending
                }
            case .title:
                entries.sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending }
            }
        }
    }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No vocabulary yet",
                    systemImage: "text.book.closed",
                    description: Text("Share a word or phrase from Translate (or any app) into Déjà Entendu to add it here.")
                )
            }
            ForEach(entries) { entry in
                NavigationLink(value: entry) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.text).font(.body)
                        Text(entry.addedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        delete(entry)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Vocabulary")
        .navigationDestination(for: VocabularyEntry.self) { entry in
            VocabularyFlashcardView(entry: entry)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(VocabularySort.allCases) { option in
                            Label(option.label, systemImage: option.icon).tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                // The system share sheet itself supplies Mail, Messages,
                // Notes, Journal, Freeform, AirDrop, Copy, etc. — nothing
                // here needs to enumerate or integrate with those apps
                // individually.
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(entries.isEmpty)
            }
        }
        .onChange(of: sortOption) { _, newValue in
            entries = newValue.sort(entries)
        }
        .sheet(isPresented: $isLanguageSheetPresented) {
            languageSelectionSheet
        }
        .task {
            // Pick up anything added elsewhere (the transcript's "Add to
            // Vocabulary" button, the Home screen's manual-add sheet) since
            // this view last loaded — those write straight to the store,
            // not through the Share Extension inbox below.
            entries = sortOption.sort(VocabularyStore.load())

            let newTexts = SharedContainer.drainPendingVocabularyTexts()
            guard !newTexts.isEmpty else { return }
            // Shared text (e.g. from Translate) carries no language of its
            // own, and without one the flashcard's speak button and
            // on-device generation both have to guess — asking here, the
            // same way audio import already asks before committing files,
            // avoids that instead of guessing after the fact.
            pendingSharedTexts = newTexts
            if !enabledLanguages.contains(pendingLanguage) {
                pendingLanguage = enabledLanguages.first ?? .chineseTraditional
            }
            isLanguageSheetPresented = true
        }
    }

    @ViewBuilder
    private var languageSelectionSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Language", selection: $pendingLanguage) {
                        ForEach(enabledLanguages, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text(pendingSharedTexts.count == 1 ? "What language is this word in?" : "What language are these words in?")
                }
            }
            .navigationTitle("Choose Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isLanguageSheetPresented = false
                        pendingSharedTexts = []
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        let newEntries = pendingSharedTexts.map {
                            VocabularyEntry(id: UUID(), text: $0, addedAt: .now, language: pendingLanguage)
                        }
                        entries = sortOption.sort(newEntries + entries)
                        VocabularyStore.save(entries)
                        pendingSharedTexts = []
                        isLanguageSheetPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func delete(_ entry: VocabularyEntry) {
        withAnimation {
            entries.removeAll { $0.id == entry.id }
        }
        VocabularyStore.save(entries)
    }
}

#Preview {
    NavigationStack {
        VocabularyListView()
    }
}
