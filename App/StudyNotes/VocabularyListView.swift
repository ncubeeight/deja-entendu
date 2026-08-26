import SwiftUI

/// Terms shared in from other apps (e.g. Translate) via the Share
/// Extension's plain-text path, plus anything added manually later.
struct VocabularyListView: View {
    @State private var entries: [VocabularyEntry] = VocabularyStore.load()
    @State private var pendingSharedTexts: [String] = []
    @State private var isLanguageSheetPresented = false
    @State private var pendingLanguage: SupportedLanguage = .chineseTraditional

    @AppStorage(AppSettings.enabledLanguagesKey) private var enabledLanguagesRaw: String = ""

    private var enabledLanguages: [SupportedLanguage] {
        let enabled = AppSettings.languages(from: enabledLanguagesRaw)
        return SupportedLanguage.allCases.filter { enabled.contains($0) }
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
                HStack {
                    NavigationLink(value: entry) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.text).font(.body)
                            Text(entry.addedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        delete(entry)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Vocabulary")
        .navigationDestination(for: VocabularyEntry.self) { entry in
            VocabularyFlashcardView(entry: entry)
        }
        .sheet(isPresented: $isLanguageSheetPresented) {
            languageSelectionSheet
        }
        .task {
            // Pick up anything added elsewhere (the transcript's "Add to
            // Vocabulary" button, the Home screen's manual-add sheet) since
            // this view last loaded — those write straight to the store,
            // not through the Share Extension inbox below.
            entries = VocabularyStore.load()

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
                        entries = newEntries + entries
                        VocabularyStore.save(entries)
                        pendingSharedTexts = []
                        isLanguageSheetPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        VocabularyStore.save(entries)
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
