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

        var ranges: [Range<String.Index>] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            ranges.append(range)
            return true
        }
        ranges = rejoinHebrewWords(ranges, in: text)

        let skippable = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        return ranges.map { String(text[$0]) }.filter { !$0.trimmingCharacters(in: skippable).isEmpty }
    }

    // MARK: - Hebrew

    /// Apple's tokenizer splits Hebrew words at marks that belong inside
    /// them: gershayim in acronyms (צה״ל → צה + ל), geresh in
    /// abbreviations and loan sounds (ג׳ירפה → ג + ירפה, ח׳ → ח) and
    /// maqaf in compounds (תל־אביב → תל + אביב). News text is full of
    /// these, often typed with plain " ' - instead, and a split word loses
    /// its ending (and its sound) on the page and on its flashcard. This
    /// glues the pieces back so each word stays exactly as written.
    private static let hebrewJoiners: Set<Character> = [
        "\u{05F4}", "\"", "\u{201D}",          // gershayim ״, " and ”
        "\u{05F3}", "'", "\u{2019}",            // geresh ׳, ' and ’
        "\u{05BE}", "-", "\u{2010}", "\u{2011}" // maqaf ־ and hyphens
    ]
    private static let hebrewGeresh: Set<Character> = ["\u{05F3}", "'", "\u{2019}"]

    private static func isHebrewLetter(_ character: Character) -> Bool {
        character.unicodeScalars.first.map { (0x05D0...0x05EA).contains($0.value) } ?? false
    }

    /// Last base letter of a token, skipping vowel points and other marks.
    private static func lastLetter(of token: Substring) -> Character? {
        token.last { $0.isLetter }
    }

    private static func rejoinHebrewWords(_ ranges: [Range<String.Index>], in text: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        for range in ranges {
            guard let previous = result.last else {
                result.append(range)
                continue
            }
            let gap = text[previous.upperBound..<range.lowerBound]
            if !gap.isEmpty,
               gap.allSatisfy({ hebrewJoiners.contains($0) }),
               gap.count <= 2,
               let before = lastLetter(of: text[previous]), isHebrewLetter(before),
               let after = text[range].first, isHebrewLetter(after) {
                result[result.count - 1] = previous.lowerBound..<range.upperBound
            } else {
                result.append(range)
            }
        }
        // A geresh right after a Hebrew word (ח׳, ג׳) is part of it.
        return result.map { range in
            guard range.upperBound < text.endIndex,
                  hebrewGeresh.contains(text[range.upperBound]),
                  let last = lastLetter(of: text[range]), isHebrewLetter(last)
            else { return range }
            return range.lowerBound..<text.index(after: range.upperBound)
        }
    }
}
