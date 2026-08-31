import Foundation
import FoundationModels

@Generable
struct SampleParagraph {
    @Guide(description: "A short, simple 3-5 sentence paragraph for a beginner language learner, using common everyday vocabulary and simple present tense. No title, no English, no commentary — only the paragraph itself.")
    var text: String
}

enum SampleTextGeneratorError: LocalizedError {
    case modelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            return "On-device sample generation isn't available right now: \(reason)"
        }
    }
}

/// Generates a short, innocuous practice paragraph on-device — for a user
/// who wants to try the app's transcript/flashcard flow but doesn't already
/// have a recording, passage, or photo of their own to import.
enum SampleTextGenerator {

    /// A small fixed pool of everyday themes, picked at random each time so
    /// repeated generations don't all read the same. Kept deliberately
    /// simple and universal (no idioms, slang, or culture-specific
    /// references) so they translate cleanly and consistently no matter
    /// which language is selected.
    static let themes: [String] = [
        "a cat going for a slow walk around a quiet garden",
        "someone making a cup of tea on a rainy morning",
        "a child feeding ducks at a park pond",
        "a family cooking a simple dinner together",
        "a dog playing fetch with a ball in a yard",
        "someone walking to a small market to buy fresh fruit",
        "a person reading a book by a window on a sunny afternoon",
        "two friends taking a short walk and talking about their day",
        "a bird building a nest in a tree outside a house",
        "someone watering plants on a balcony in the morning",
    ]

    static func generateParagraph(language: SupportedLanguage) async throws -> String {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw SampleTextGeneratorError.modelUnavailable(String(describing: reason))
        }

        let theme = themes.randomElement() ?? themes[0]

        let session = LanguageModelSession(
            model: model,
            instructions: """
            You are a language-learning content writer. Write a short, \
            simple practice paragraph in \(language.displayName), using its \
            native script, about: \(theme). Keep it to 3-5 short sentences \
            using common everyday vocabulary and simple present tense — \
            suitable for a beginner learner. Do not include a title, an \
            English translation, or any commentary — only the paragraph \
            itself, written entirely in \(language.displayName).
            """
        )

        let response = try await session.respond(
            to: "Write the paragraph now.",
            generating: SampleParagraph.self,
            options: GenerationOptions(maximumResponseTokens: 300)
        )

        return response.content.text
    }
}
