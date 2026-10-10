import Foundation
import os

/// Persists the user's custom glossary the same way VocabularyStore
/// persists vocabulary — a JSON file in the app's own container.
enum GlossaryStore {
    private static let fileName = "glossary.json"

    /// Just what a lookup needs — no IDs or dates — so a connected
    /// dictionary with 100k+ terms stays small resident in memory.
    private struct IndexedDefinition {
        let definition: String
        let language: SupportedLanguage
        let isManual: Bool
    }

    /// Folded term → matches in file order. Built lazily on the first
    /// lookup and dropped on every save(), so it can't go stale. Before
    /// this, every lookup decoded all of glossary.json — measured at
    /// ~0.3s and +110 MB peak for a 120k-entry dictionary, and the
    /// flashcard did that twice per redraw on the main thread.
    /// `generation` bumps on every save so an index built from data a save
    /// has since replaced is never stored.
    private struct IndexState {
        var generation = 0
        var terms: [String: [IndexedDefinition]]?
    }
    private static let index = OSAllocatedUnfairLock(initialState: IndexState())

    private static func indexKey(_ term: String) -> String {
        // Same case folding caseInsensitiveCompare uses, so lookups match
        // exactly what the old linear scan matched.
        term.folding(options: .caseInsensitive, locale: nil)
    }

    private static func buildIndex() -> [String: [IndexedDefinition]] {
        var built: [String: [IndexedDefinition]] = [:]
        for entry in load() {
            built[indexKey(entry.term), default: []].append(IndexedDefinition(
                definition: entry.definition,
                language: entry.language,
                isManual: entry.source == .manual
            ))
        }
        return built
    }

    private static func fileURL() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(fileName)
    }

    static func load() -> [GlossaryEntry] {
        guard
            let url = try? fileURL(),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([GlossaryEntry].self, from: data)
        else { return [] }
        return entries
    }

    static func save(_ entries: [GlossaryEntry]) {
        guard let url = try? fileURL(), let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
        index.withLock {
            $0.generation += 1
            $0.terms = nil
        }
    }

    /// Case-insensitive exact match on term, preferring one tagged with the
    /// given language when there's ambiguity (the same spelled word could
    /// exist in more than one language's glossary). Falls back to any
    /// language match if the term's language isn't known. Terms from a
    /// connected dictionary only count while that dictionary's language is
    /// toggled on in Settings' "Languages shown on import" — that toggle is
    /// how a connected dictionary is turned off and on without
    /// disconnecting it. Hand-typed terms always apply.
    ///
    /// The first call after launch or a save builds the index (one full
    /// read of glossary.json), so call this off the main thread.
    static func definition(forTerm term: String, language: SupportedLanguage?) -> String? {
        let candidates: [IndexedDefinition]
        let (cached, generation) = index.withLock { ($0.terms, $0.generation) }
        if let cached {
            candidates = cached[indexKey(term)] ?? []
        } else {
            // Built outside the lock so a slow first build doesn't block
            // other callers.
            let built = buildIndex()
            index.withLock {
                if $0.generation == generation { $0.terms = built }
            }
            candidates = built[indexKey(term)] ?? []
        }

        let enabled = AppSettings.languages(from: UserDefaults.standard.string(forKey: AppSettings.enabledLanguagesKey) ?? "")
        let matches = candidates.filter { $0.isManual || enabled.contains($0.language) }
        if let language, let exact = matches.first(where: { $0.language == language }) {
            return exact.definition
        }
        return matches.first?.definition
    }
}
