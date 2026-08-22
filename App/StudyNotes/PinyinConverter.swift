import Foundation

/// Deterministic hanzi -> pinyin conversion using Apple's built-in
/// linguistic tables. Deliberately NOT using the LLM for this — it's
/// cheaper, faster, and more reliable than asking a small on-device model
/// to do phonetic transcription.
enum PinyinConverter {
    static func pinyin(for mandarinText: String) -> String {
        let mutable = NSMutableString(string: mandarinText) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false) // drop for tone-mark-free; remove this line to keep tone marks
        return mutable as String
    }

    /// Same conversion but keeping tone marks (üà, etc.) — usually what you
    /// actually want for a study app.
    static func pinyinWithToneMarks(for mandarinText: String) -> String {
        let mutable = NSMutableString(string: mandarinText) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)
        return mutable as String
    }
}
