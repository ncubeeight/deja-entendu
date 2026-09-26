import SwiftUI

/// One glossary the user can open from the Custom Glossary page: either one
/// of their connected dictionary files, or the terms they typed in by hand.
enum GlossaryScope: Hashable {
    case dictionary(id: UUID, title: String)
    case manual

    var title: String {
        switch self {
        case .dictionary(_, let title): title
        case .manual: "My Terms"
        }
    }

    func contains(_ entry: GlossaryEntry) -> Bool {
        switch self {
        case .dictionary(let id, _): entry.dictionaryID == id
        case .manual: entry.source == .manual
        }
    }
}

/// The user's glossaries at a glance — every dictionary file they've
/// connected (each in its own language) plus the terms they typed in
/// themselves. Deliberately shows only the list of glossaries, not their
/// contents: a connected dictionary can hold tens of thousands of terms, so
/// tapping one opens GlossaryTermsView, where they can search it and pick
/// terms to send to Vocabulary. Looked up ahead of FlashcardGenerator on the
/// flashcard page, and still useful on devices with no on-device model at
/// all.
struct CustomGlossaryView: View {
    @State private var dictionaries: [ConnectedDictionary] = ConnectedDictionaryStore.load()
    @State private var termCounts: [UUID: Int] = [:]
    @State private var manualCount = 0
    @State private var isAddSheetPresented = false
    @State private var isConnectSheetPresented = false
    @State private var dictionaryToDisconnect: ConnectedDictionary?

    @AppStorage(AppSettings.enabledLanguagesKey) private var enabledLanguagesRaw: String = ""

    private var enabledLanguages: Set<SupportedLanguage> {
        AppSettings.languages(from: enabledLanguagesRaw)
    }

    var body: some View {
        List {
            if dictionaries.isEmpty && manualCount == 0 {
                ContentUnavailableView(
                    "No glossaries yet",
                    systemImage: "character.book.closed",
                    description: Text("Connect a dictionary file, or add a term with your own definition — it'll be shown on that word's flashcard instead of (or alongside) an on-device guess.")
                )
            }

            if !dictionaries.isEmpty {
                Section {
                    ForEach(dictionaries) { dictionary in
                        NavigationLink {
                            GlossaryTermsView(scope: .dictionary(id: dictionary.id, title: dictionary.language.displayName))
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(dictionary.language.displayName).font(.body.weight(.semibold))
                                    if !enabledLanguages.contains(dictionary.language) {
                                        Text("Off")
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.quaternary, in: Capsule())
                                    }
                                }
                                Text("\(dictionary.fileName) · \(termCounts[dictionary.id] ?? dictionary.termCount) terms")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                dictionaryToDisconnect = dictionary
                            } label: {
                                Label("Disconnect", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Connected Dictionaries")
                } footer: {
                    Text("Tap a dictionary to browse and search its terms. Turn a dictionary's language off and on in Settings under \"Languages shown on import\".")
                }
            }

            if manualCount > 0 {
                Section {
                    NavigationLink {
                        GlossaryTermsView(scope: .manual)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("My Terms").font(.body.weight(.semibold))
                            Text("\(manualCount) term\(manualCount == 1 ? "" : "s") you added")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Custom Glossary")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        isConnectSheetPresented = true
                    } label: {
                        Label("Connect Dictionary File", systemImage: "folder.badge.plus")
                    }
                    Button {
                        isAddSheetPresented = true
                    } label: {
                        Label("Add Term", systemImage: "plus")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .task { refresh() }
        .sheet(isPresented: $isAddSheetPresented, onDismiss: refresh) {
            AddGlossaryEntryView()
        }
        .sheet(isPresented: $isConnectSheetPresented, onDismiss: refresh) {
            ConnectLocalDictionaryView()
        }
        .confirmationDialog(
            "Disconnect \(dictionaryToDisconnect?.language.displayName ?? "") dictionary?",
            isPresented: Binding(
                get: { dictionaryToDisconnect != nil },
                set: { if !$0 { dictionaryToDisconnect = nil } }
            ),
            titleVisibility: .visible,
            presenting: dictionaryToDisconnect
        ) { dictionary in
            Button("Disconnect", role: .destructive) { disconnect(dictionary) }
            Button("Cancel", role: .cancel) {}
        } message: { dictionary in
            Text("Removes its \(termCounts[dictionary.id] ?? dictionary.termCount) terms from your glossary. Terms you typed in yourself and terms already added to Vocabulary aren't affected.")
        }
    }

    private func refresh() {
        dictionaries = ConnectedDictionaryStore.load()
        let entries = GlossaryStore.load()
        manualCount = entries.filter { $0.source == .manual }.count
        var counts: [UUID: Int] = [:]
        for entry in entries {
            if let id = entry.dictionaryID { counts[id, default: 0] += 1 }
        }
        termCounts = counts
    }

    private func disconnect(_ dictionary: ConnectedDictionary) {
        var entries = GlossaryStore.load()
        entries.removeAll { $0.dictionaryID == dictionary.id }
        GlossaryStore.save(entries)
        ConnectedDictionaryStore.remove(id: dictionary.id)

        // The default Samples language follows the most recently connected
        // dictionary — fall back to the next one, or clear it.
        if let latest = ConnectedDictionaryStore.load().first {
            UserDefaults.standard.set(latest.language.rawValue, forKey: AppSettings.defaultImportLanguageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: AppSettings.defaultImportLanguageKey)
        }
        withAnimation { refresh() }
    }
}

/// Browses one glossary's terms. Searchable across terms and definitions
/// (a connected dictionary can be far too long to scroll A–Z), and terms
/// can be selected and added to Vocabulary — where each becomes a flashcard
/// that shows this glossary's definition.
struct GlossaryTermsView: View {
    let scope: GlossaryScope

    @State private var entries: [GlossaryEntry] = []
    @State private var visibleEntries: [GlossaryEntry] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var editMode: EditMode = .inactive
    @State private var selection: Set<UUID> = []
    @State private var vocabularyKeys: Set<String> = []
    @State private var addResult: String?

    private static func key(_ term: String, _ language: SupportedLanguage?) -> String {
        "\(language?.rawValue ?? "")::\(term.lowercased())"
    }

    /// A Vocabulary term with no language recorded still counts as the same
    /// term, so it isn't added a second time.
    private func isInVocabulary(_ term: String, _ language: SupportedLanguage, in keys: Set<String>) -> Bool {
        keys.contains(Self.key(term, language)) || keys.contains(Self.key(term, nil))
    }

    var body: some View {
        List(selection: $selection) {
            if !isLoading && visibleEntries.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView("No terms", systemImage: "character.book.closed")
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            ForEach(visibleEntries) { entry in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(entry.term).font(.body.weight(.semibold))
                        Spacer()
                        if isInVocabulary(entry.term, entry.language, in: vocabularyKeys) {
                            Label("In Vocabulary", systemImage: "checkmark")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(entry.definition)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        addToVocabulary([entry])
                    } label: {
                        Label("Add to Vocabulary", systemImage: "text.book.closed")
                    }
                    .tint(.accentColor)
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
        .overlay {
            if isLoading { ProgressView() }
        }
        .navigationTitle(scope.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search terms and definitions")
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(editMode.isEditing ? "Done" : "Select") {
                    withAnimation {
                        editMode = editMode.isEditing ? .inactive : .active
                        if !editMode.isEditing { selection = [] }
                    }
                }
                .disabled(entries.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if editMode.isEditing && !selection.isEmpty {
                Button {
                    addToVocabulary(entries.filter { selection.contains($0.id) })
                    selection = []
                    editMode = .inactive
                } label: {
                    Text("Add \(selection.count) to Vocabulary")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .task { await load() }
        .task(id: searchText) { await applySearch() }
        .alert(
            "Vocabulary",
            isPresented: Binding(get: { addResult != nil }, set: { if !$0 { addResult = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(addResult ?? "")
        }
    }

    private func load() async {
        let scope = scope
        let loaded = await Task.detached(priority: .userInitiated) {
            GlossaryStore.load()
                .filter { scope.contains($0) }
                .sorted { $0.term.localizedStandardCompare($1.term) == .orderedAscending }
        }.value
        entries = loaded
        visibleEntries = loaded
        vocabularyKeys = Set(VocabularyStore.load().map { Self.key($0.text, $0.language) })
        isLoading = false
        await applySearch()
    }

    /// Debounced so typing in a very large dictionary doesn't refilter on
    /// every keystroke, and filtered off the main thread.
    private func applySearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            visibleEntries = entries
            return
        }
        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else { return }
        let source = entries
        let matches = await Task.detached(priority: .userInitiated) {
            source.filter {
                $0.term.localizedCaseInsensitiveContains(query) || $0.definition.localizedCaseInsensitiveContains(query)
            }
        }.value
        guard !Task.isCancelled else { return }
        visibleEntries = matches
    }

    private func addToVocabulary(_ chosen: [GlossaryEntry]) {
        var vocabulary = VocabularyStore.load()
        var existingKeys = Set(vocabulary.map { Self.key($0.text, $0.language) })
        var added = 0
        for entry in chosen {
            guard !isInVocabulary(entry.term, entry.language, in: existingKeys) else { continue }
            existingKeys.insert(Self.key(entry.term, entry.language))
            vocabulary.insert(VocabularyEntry(id: UUID(), text: entry.term, addedAt: .now, language: entry.language), at: 0)
            added += 1
        }
        VocabularyStore.save(vocabulary)
        vocabularyKeys = existingKeys
        let skipped = chosen.count - added
        addResult = added == 0
            ? "\(chosen.count == 1 ? "That term is" : "Those terms are") already in your Vocabulary."
            : "Added \(added) term\(added == 1 ? "" : "s") to Vocabulary." + (skipped > 0 ? " \(skipped) already there." : "")
    }

    private func delete(_ entry: GlossaryEntry) {
        var all = GlossaryStore.load()
        all.removeAll { $0.id == entry.id }
        GlossaryStore.save(all)
        entries.removeAll { $0.id == entry.id }
        visibleEntries.removeAll { $0.id == entry.id }
    }
}

private struct AddGlossaryEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var term: String = ""
    @State private var definition: String = ""
    @State private var language: SupportedLanguage = .chineseTraditional

    @AppStorage(AppSettings.enabledLanguagesKey) private var enabledLanguagesRaw: String = ""

    private var enabledLanguages: [SupportedLanguage] {
        let enabled = AppSettings.languages(from: enabledLanguagesRaw)
        return SupportedLanguage.allCases.filter { enabled.contains($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Term", text: $term)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Picker("Language", selection: $language) {
                        ForEach(enabledLanguages, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                }

                Section {
                    TextEditor(text: $definition)
                        .frame(minHeight: 100)
                } header: {
                    Text("Your Definition")
                } footer: {
                    Text("Shown on this term's flashcard as-is — nothing is generated or altered.")
                }
            }
            .onAppear {
                if !enabledLanguages.contains(language) {
                    language = enabledLanguages.first ?? .chineseTraditional
                }
            }
            .navigationTitle("Add Term")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(
                            term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDefinition = definition.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty, !trimmedDefinition.isEmpty else { return }

        var entries = GlossaryStore.load()
        entries.insert(GlossaryEntry(id: UUID(), term: trimmedTerm, definition: trimmedDefinition, language: language, addedAt: .now), at: 0)
        GlossaryStore.save(entries)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        CustomGlossaryView()
    }
}
