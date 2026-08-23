import Foundation
import NaturalLanguage

/// Splits transcript text into sentences and words using Apple's
/// NaturalLanguage tokenizer — critical for Chinese/Japanese, which have no
/// whitespace to split on, so a naive `.split(separator: " ")` would just
/// return the whole line as one "word".
enum TextSegmentation {
    static func sentences(in text: String, language: NLLanguage) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.setLanguage(language)
        tokenizer.string = text

        var result: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { result.append(sentence) }
            return true
        }
        return result.isEmpty ? [text] : result
    }

    /// Word tokens only — punctuation-only tokens (periods, commas, 。 、 etc.)
    /// are dropped since they're not meaningful vocabulary entries.
    static func words(in text: String, language: NLLanguage) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.setLanguage(language)
        tokenizer.string = text

        let skippable = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)

        var result: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range])
            if !word.trimmingCharacters(in: skippable).isEmpty {
                result.append(word)
            }
            return true
        }
        return result
    }
}
