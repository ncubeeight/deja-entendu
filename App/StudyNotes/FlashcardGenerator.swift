import Foundation
import FoundationModels

@Generable
struct FlashcardDetails {
    @Guide(description: "A simple phonetic pronunciation guide using plain English spelling, not IPA — e.g. 'boh-ZHOOR'.")
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

    /// Vocabulary entries don't carry a known source language (they arrive
    /// as freeform text from Translate, manual entry, or a tapped transcript
    /// word), so the model is asked to identify the language itself as part
    /// of the same pass, rather than requiring it as an input.
    static func generateDetails(forTerm term: String) async throws -> FlashcardDetails {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw FlashcardError.modelUnavailable(String(describing: reason))
        }

        let session = LanguageModelSession(
            model: model,
            instructions: """
            You are a compact language-learning dictionary. Given a word or \
            short phrase, first identify what language it's in, then produce \
            a pronunciation guide, a translation, and a short natural example \
            sentence using the term in that language — plus that sentence's \
            English translation.
            """
        )

        let response = try await session.respond(
            to: "Term: \(term)",
            generating: FlashcardDetails.self,
            options: GenerationOptions(maximumResponseTokens: 300)
        )

        return response.content
    }
}
