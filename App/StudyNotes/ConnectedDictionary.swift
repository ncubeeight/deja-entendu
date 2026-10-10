import Foundation

/// Metadata for one of the user's own dictionary files, connected from
/// Files/Finder rather than typed in by hand or downloaded from Apple's
/// Translate packs (see DictionaryLanguagePacksSection). Any number can be
/// connected — each contributes its terms to the glossary tagged with its
/// `id` (GlossaryEntry.dictionaryID), so disconnecting one removes only its
/// own terms. Hand-typed GlossaryEntry rows are never touched.
///
/// bookmarkData keeps a security-scoped reference to the original file
/// alive across launches per Apple's sandboxing rules for files picked
/// outside the app's own container — kept for a possible future "re-sync"
/// action, since the parsed terms themselves are already copied into
/// GlossaryStore at connect time and don't require the file to stay
/// reachable.
struct ConnectedDictionary: Codable, Identifiable, Hashable {
    let id: UUID
    let fileName: String
    let language: SupportedLanguage
    let connectedAt: Date
    let termCount: Int
    let bookmarkData: Data

    init(id: UUID = UUID(), fileName: String, language: SupportedLanguage, connectedAt: Date, termCount: Int, bookmarkData: Data) {
        self.id = id
        self.fileName = fileName
        self.language = language
        self.connectedAt = connectedAt
        self.termCount = termCount
        self.bookmarkData = bookmarkData
    }

    /// Custom-decoded so the single-dictionary file saved before `id`
    /// existed still loads (it gets a fresh ID, persisted right away by
    /// ConnectedDictionaryStore's migration).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        fileName = try container.decode(String.self, forKey: .fileName)
        language = try container.decode(SupportedLanguage.self, forKey: .language)
        connectedAt = try container.decode(Date.self, forKey: .connectedAt)
        termCount = try container.decode(Int.self, forKey: .termCount)
        bookmarkData = try container.decode(Data.self, forKey: .bookmarkData)
    }
}

enum ConnectedDictionaryStore {
    private static let fileName = "connected-dictionaries.json"
    private static let legacyFileName = "connected-dictionary.json"

    private static func documentsURL(_ name: String) throws -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
    }

    /// Most recently connected first. On first launch after upgrading from
    /// the one-dictionary version, migrates that file into the new list and
    /// stamps its terms in the glossary with its ID.
    static func load() -> [ConnectedDictionary] {
        if
            let url = try? documentsURL(fileName),
            let data = try? Data(contentsOf: url),
            let dictionaries = try? JSONDecoder().decode([ConnectedDictionary].self, from: data)
        {
            return dictionaries
        }
        return migrateLegacy()
    }

    static func save(_ dictionaries: [ConnectedDictionary]) {
        guard let url = try? documentsURL(fileName), let data = try? JSONEncoder().encode(dictionaries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func add(_ dictionary: ConnectedDictionary) {
        save([dictionary] + load())
    }

    static func remove(id: UUID) {
        save(load().filter { $0.id != id })
    }

    private static func migrateLegacy() -> [ConnectedDictionary] {
        guard
            let legacyURL = try? documentsURL(legacyFileName),
            let data = try? Data(contentsOf: legacyURL),
            let legacy = try? JSONDecoder().decode(ConnectedDictionary.self, from: data)
        else { return [] }

        var entries = GlossaryStore.load()
        for index in entries.indices where entries[index].source == .connectedDictionary && entries[index].dictionaryID == nil {
            entries[index].dictionaryID = legacy.id
        }
        GlossaryStore.save(entries)
        save([legacy])
        try? FileManager.default.removeItem(at: legacyURL)
        return [legacy]
    }
}
