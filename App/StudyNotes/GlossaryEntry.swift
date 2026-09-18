import Foundation

/// A term/definition pair in the user's glossary — either typed in by hand
/// or bulk-imported from a dictionary file the user connected from Files
/// (see ConnectLocalDictionaryView). Specialized vocabulary an on-device
/// model wouldn't reliably know, or just an authoritative answer instead
/// of a generated one. Looked up before/alongside FlashcardGenerator, and
/// available even on devices with no on-device model at all.
struct GlossaryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let term: String
    let definition: String
    let language: SupportedLanguage
    let addedAt: Date
    var source: GlossarySource = .manual

    enum CodingKeys: String, CodingKey {
        case id, term, definition, language, addedAt, source
    }

    init(id: UUID, term: String, definition: String, language: SupportedLanguage, addedAt: Date, source: GlossarySource = .manual) {
        self.id = id
        self.term = term
        self.definition = definition
        self.language = language
        self.addedAt = addedAt
        self.source = source
    }

    /// Custom-decoded so glossary.json files saved before `source` existed
    /// still load — a missing key defaults to .manual rather than failing
    /// to decode the whole file.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        term = try container.decode(String.self, forKey: .term)
        definition = try container.decode(String.self, forKey: .definition)
        language = try container.decode(SupportedLanguage.self, forKey: .language)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
        source = try container.decodeIfPresent(GlossarySource.self, forKey: .source) ?? .manual
    }
}

/// Where a GlossaryEntry came from — lets a reconnect/disconnect of a
/// local dictionary replace just the terms it contributed without
/// touching anything the user typed in themselves.
enum GlossarySource: String, Codable, Hashable {
    case manual
    case connectedDictionary
}
