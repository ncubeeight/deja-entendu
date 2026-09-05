import SwiftUI

/// Lets the user manage their own term/definition pairs — specialized
/// vocabulary an on-device model might not know, or just a personal
/// glossary they want treated as authoritative. Looked up ahead of
/// FlashcardGenerator on the flashcard page, and still useful on devices
/// with no on-device model at all.
struct CustomGlossaryView: View {
    @State private var entries: [GlossaryEntry] = GlossaryStore.load()
    @State private var isAddSheetPresented = false

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No custom terms yet",
                    systemImage: "character.book.closed",
                    description: Text("Add a term and your own definition — it'll be shown on that word's flashcard instead of (or alongside) an on-device guess.")
                )
            }
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.term).font(.body.weight(.semibold))
                        Spacer()
                        Text(entry.language.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.definition)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Custom Glossary")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddSheetPresented = true
                } label: {
                    Label("Add Term", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddSheetPresented, onDismiss: {
            entries = GlossaryStore.load()
        }) {
            AddGlossaryEntryView()
        }
    }

    private func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        GlossaryStore.save(entries)
    }
}

private struct AddGlossaryEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var term: String = ""
    @State private var definition: String = ""
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
                    TextField("Term", text: $term)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Picker("Language", selection: $language) {
                        ForEach(enabledLanguages, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                }

                Section {
                    TextEditor(text: $definition)
                        .frame(minHeight: 100)
                } header: {
                    Text("Your Definition")
                } footer: {
                    Text("Shown on this term's flashcard as-is — nothing is generated or altered.")
                }
            }
            .onAppear {
                if !enabledLanguages.contains(language) {
                    language = enabledLanguages.first ?? .chineseTraditional
                }
            }
            .navigationTitle("Add Term")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(
                            term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDefinition = definition.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty, !trimmedDefinition.isEmpty else { return }

        var entries = GlossaryStore.load()
        entries.insert(GlossaryEntry(id: UUID(), term: trimmedTerm, definition: trimmedDefinition, language: language, addedAt: .now), at: 0)
        GlossaryStore.save(entries)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        CustomGlossaryView()
    }
}
