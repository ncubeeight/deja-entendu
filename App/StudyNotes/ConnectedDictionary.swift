import Foundation

/// Metadata for the user's own dictionary file, connected from Files/
/// Finder rather than typed in by hand or downloaded from Apple's
/// Translate packs (see DictionaryLanguagePacksSection). Only one can be
/// connected at a time — connecting a new file replaces it, and its terms
/// replace the previous connection's terms in the glossary (hand-typed
/// GlossaryEntry rows are untouched, see GlossarySource).
///
/// bookmarkData keeps a security-scoped reference to the original file
/// alive across launches per Apple's sandboxing rules for files picked
/// outside the app's own container — kept for a possible future "re-sync"
/// action, since the parsed terms themselves are already copied into
/// GlossaryStore at connect time and don't require the file to stay
/// reachable.
struct ConnectedDictionary: Codable {
    let fileName: String
    let language: SupportedLanguage
    let connectedAt: Date
    let termCount: Int
    let bookmarkData: Data
}

enum ConnectedDictionaryStore {
    private static let fileName = "connected-dictionary.json"

    private static func fileURL() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(fileName)
    }

    static func load() -> ConnectedDictionary? {
        guard
            let url = try? fileURL(),
            let data = try? Data(contentsOf: url),
            let dictionary = try? JSONDecoder().decode(ConnectedDictionary.self, from: data)
        else { return nil }
        return dictionary
    }

    static func save(_ dictionary: ConnectedDictionary) {
        guard let url = try? fileURL(), let data = try? JSONEncoder().encode(dictionary) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func clear() {
        guard let url = try? fileURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
