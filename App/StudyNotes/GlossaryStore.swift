import Foundation

/// Persists the user's custom glossary the same way VocabularyStore
/// persists vocabulary — a JSON file in the app's own container.
enum GlossaryStore {
    private static let fileName = "glossary.json"

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
    }

    /// Case-insensitive exact match on term, preferring one tagged with the
    /// given language when there's ambiguity (the same spelled word could
    /// exist in more than one language's glossary). Falls back to any
    /// language match if the term's language isn't known.
    static func definition(forTerm term: String, language: SupportedLanguage?) -> String? {
        let entries = load()
        let matches = entries.filter { $0.term.caseInsensitiveCompare(term) == .orderedSame }
        if let language, let exact = matches.first(where: { $0.language == language }) {
            return exact.definition
        }
        return matches.first?.definition
    }
}
