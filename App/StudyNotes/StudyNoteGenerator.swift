import Foundation
import FoundationModels

/// Structured output from the on-device Foundation Models LLM. Using
/// @Generable/@Guide instead of freeform text keeps a small on-device model
/// reliable — it fills in a schema rather than free-associating.
@Generable
struct StudyNotes {
    @Guide(description: "Natural English translation of the transcript, 1-2 sentences.")
    var englishTranslation: String

    @Guide(description: "Up to 5 notable vocabulary words from the transcript, in Traditional Chinese.", .maximumCount(5))
    var keyVocabulary: [String]

    @Guide(description: "One short, encouraging note about grammar or phrasing, max 2 sentences.")
    var grammarNote: String
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

    static func generateNotes(forTranscript transcript: String) async throws -> StudyNotes {
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
            You help a student studying Taiwanese Mandarin (Traditional characters, \
            Taiwan usage). Given a transcript of their spoken practice, translate it \
            and give brief, encouraging feedback. Keep responses short.
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
