import SwiftUI

/// A lightweight manual entry point for a text sample — the text-import
/// counterpart to AddVocabularyWordView, but for a whole passage rather
/// than a single word. Saves straight into ImportedTextSampleStore and
/// dismisses, same self-contained pattern.
struct TextImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var body_: String = ""
    @State private var language: SupportedLanguage = .chineseTraditional

    @AppStorage(AppSettings.enabledLanguagesKey) private var enabledLanguagesRaw: String = ""

    private var enabledLanguages: [SupportedLanguage] {
        let enabled = AppSettings.languages(from: enabledLanguagesRaw)
        return SupportedLanguage.allCases.filter { enabled.contains($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $body_)
                        .frame(minHeight: 160)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Text")
                } footer: {
                    Text("Paste or type a passage in the language you're studying.")
                }

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
            .navigationTitle("Add Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(body_.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = body_.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var entries = ImportedTextSampleStore.load()
        entries.insert(ImportedTextSample(id: UUID(), body: trimmed, importedAt: .now, language: language), at: 0)
        ImportedTextSampleStore.save(entries)
        dismiss()
    }
}

#Preview {
    TextImportView()
}
