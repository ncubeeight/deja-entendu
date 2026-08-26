import SwiftUI

/// A lightweight manual entry point for the vocabulary list — the
/// counterpart to sharing text in from Translate via the Share Extension,
/// for when a user just wants to type a word directly instead.
struct AddVocabularyWordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var language: SupportedLanguage = .chineseTraditional

    @AppStorage(AppSettings.enabledLanguagesKey) private var enabledLanguagesRaw: String = ""

    private var enabledLanguages: [SupportedLanguage] {
        let enabled = AppSettings.languages(from: enabledLanguagesRaw)
        return SupportedLanguage.allCases.filter { enabled.contains($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Word or phrase", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    // This field takes words in any supported language —
                    // English autocorrect actively corrupts non-English
                    // input (e.g. silently turned "Bonsoir" into "No sour"
                    // in testing), so it must stay off.
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                // Without a known language, the flashcard's speak button
                // and on-device generation both have to guess — a bare
                // word can look like more than one language, so guessing
                // sometimes picked the wrong one (or fell back to reading
                // it with English pronunciation rules). Asking up front
                // avoids that instead of trying to detect it after the fact.
                Picker("Language", selection: $language) {
                    ForEach(enabledLanguages, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            }
            .onAppear {
                if !enabledLanguages.contains(language) {
                    language = enabledLanguages.first ?? .chineseTraditional
                }
            }
            .navigationTitle("Add a Word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var entries = VocabularyStore.load()
        entries.insert(VocabularyEntry(id: UUID(), text: trimmed, addedAt: .now, language: language), at: 0)
        VocabularyStore.save(entries)
        dismiss()
    }
}

#Preview {
    AddVocabularyWordView()
}
