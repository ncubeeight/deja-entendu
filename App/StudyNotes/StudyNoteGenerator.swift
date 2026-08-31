import Foundation
import FoundationModels

/// Structured output from the on-device Foundation Models LLM. Using
/// @Generable/@Guide instead of freeform text keeps a small on-device model
/// reliable — it fills in a schema rather than free-associating.
@Generable
struct StudyNotes {
    @Guide(description: "Natural English translation of the transcript, 1-2 sentences.")
    var englishTranslation: String

    @Guide(description: "Up to 5 notable vocabulary words or phrases from the transcript, written in their original script.", .maximumCount(5))
    var keyVocabulary: [String]
}

enum StudyNoteError: LocalizedError {
    case modelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            return "On-device study notes aren't available right now: \(reason)"
        }
    }
}

enum StudyNoteGenerator {

    static func generateNotes(forTranscript transcript: String, language: SupportedLanguage) async throws -> StudyNotes {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw StudyNoteError.modelUnavailable(String(describing: reason))
        }

        // Fresh session per transcript — the on-device model's context window
        // is only 4096 tokens, so don't accumulate history across recordings.
        let session = LanguageModelSession(
            model: model,
            instructions: """
            You help a student studying \(language.displayName). Given a transcript, \
            translate it into English and pull out notable vocabulary. Only translate \
            and extract — do not comment on, evaluate, or offer feedback about the \
            content, correctness, or meaning of the transcript; you don't know the \
            context it came from.
            """
        )

        let response = try await session.respond(
            to: "Transcript:\n\(transcript)",
            generating: StudyNotes.self,
            options: GenerationOptions(maximumResponseTokens: 300)
        )

        return response.content
    }
}
