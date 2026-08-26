import Foundation
import FoundationModels

@Generable
struct FlashcardDetails {
    @Guide(description: """
    A simple phonetic pronunciation guide using plain English spelling, not \
    IPA. It must sound out the term's ENTIRE original text from first \
    syllable to last — never a truncated stem, prefix, or shortened form. \
    e.g. for the 2-syllable term "Bonjour", 'boh-ZHOOR' (both syllables); \
    for the 3-syllable term "réfléchi", 'ray-flay-SHEE' (all three \
    syllables, not just 'ray-flay'). Every syllable of the original term \
    must be represented.
    """)
    var pronunciation: String

    @Guide(description: "A brief, natural English translation or definition of the term.")
    var translation: String

    @Guide(description: "A short, natural example sentence in the term's own language and script, using the term.")
    var exampleSentence: String

    @Guide(description: "An English translation of the example sentence.")
    var exampleTranslation: String
}

enum FlashcardError: LocalizedError {
    case modelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            return "On-device flashcard details aren't available right now: \(reason)"
        }
    }
}

enum FlashcardGenerator {

    /// When the entry came from a tapped transcript word, `language` is
    /// already known from the recording it was tagged with — pass it so the
    /// model doesn't have to guess (a bare word like "commandera" can look
    /// like Spanish/Italian as easily as French, and got that wrong before
    /// this was threaded through). Entries without a known language (freeform
    /// text from Translate, manual entry) still ask the model to identify it.
    static func generateDetails(forTerm term: String, language: SupportedLanguage?) async throws -> FlashcardDetails {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw FlashcardError.modelUnavailable(String(describing: reason))
        }

        let instructions: String
        if let language {
            instructions = """
            You are a compact language-learning dictionary. The user will give \
            you a word or short phrase in \(language.displayName) — treat that \
            as certain, do not second-guess or reinterpret it as another \
            language even if it also resembles a word in one. Produce a \
            pronunciation guide, a translation, and a short natural example \
            sentence in \(language.displayName) using the term — plus that \
            sentence's English translation. The pronunciation guide must \
            cover the term's full length, every syllable from start to \
            finish — never just a stem or the first part of a longer word.
            """
        } else {
            instructions = """
            You are a compact language-learning dictionary. Given a word or \
            short phrase, first identify what language it's in, then produce \
            a pronunciation guide, a translation, and a short natural example \
            sentence using the term in that language — plus that sentence's \
            English translation. The pronunciation guide must cover the \
            term's full length, every syllable from start to finish — never \
            just a stem or the first part of a longer word.
            """
        }

        let session = LanguageModelSession(model: model, instructions: instructions)

        let response = try await session.respond(
            to: "Term: \(term)",
            generating: FlashcardDetails.self,
            options: GenerationOptions(maximumResponseTokens: 300)
        )

        return response.content
    }
}
