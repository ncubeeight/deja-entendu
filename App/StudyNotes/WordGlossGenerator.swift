import Foundation
import FoundationModels

@Generable
struct WordGloss {
    @Guide(description: "A concise 1-4 word English gloss for the given word or phrase. No punctuation, no romaji.")
    var englishGloss: String
}

enum WordGlossError: LocalizedError {
    case modelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            return "On-device definitions aren't available right now: \(reason)"
        }
    }
}

enum WordGlossGenerator {

    /// Looks up a short English gloss for a single word/clause, using the
    /// surrounding line as context. Fresh session per lookup, same reasoning
    /// as StudyNoteGenerator — keep the small on-device model's limited
    /// context window free of unrelated history.
    static func gloss(forWord word: String, inLine line: String) async throws -> String {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw WordGlossError.modelUnavailable(String(describing: reason))
        }

        let session = LanguageModelSession(
            model: model,
            instructions: """
            You are a compact classical-Japanese-to-English dictionary. Given a \
            short word or clause and the line of poetry it's drawn from, respond \
            with only a brief, plain English gloss for that word — not a \
            translation of the whole line.
            """
        )

        let response = try await session.respond(
            to: "Word: \(word)\nLine: \(line)",
            generating: WordGloss.self,
            options: GenerationOptions(maximumResponseTokens: 60)
        )

        return response.content.englishGloss
    }

    /// General-purpose counterpart to gloss(forWord:inLine:) — that one's
    /// instructions are hardcoded to classical Japanese poetry for
    /// IrohaExplorerView, so it isn't a fit for the Samples tab's tap-to-see
    /// tooltip, which needs a quick gloss for any supported language.
    static func gloss(forWord word: String, language: SupportedLanguage) async throws -> String {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw WordGlossError.modelUnavailable(String(describing: reason))
        }

        let session = LanguageModelSession(
            model: model,
            instructions: """
            You are a compact \(language.displayName)-to-English dictionary. \
            Given a short word or phrase in \(language.displayName), respond \
            with only a brief, plain English gloss for it — a few words, not \
            a full sentence or definition.
            """
        )

        let response = try await session.respond(
            to: "Word: \(word)",
            generating: WordGloss.self,
            options: GenerationOptions(maximumResponseTokens: 60)
        )

        return response.content.englishGloss
    }
}
