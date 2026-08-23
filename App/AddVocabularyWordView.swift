import SwiftUI

/// A lightweight manual entry point for the vocabulary list — the
/// counterpart to sharing text in from Translate via the Share Extension,
/// for when a user just wants to type a word directly instead.
struct AddVocabularyWordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Word or phrase", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    // This field takes words in any of the 5 supported
                    // languages — English autocorrect actively corrupts
                    // non-English input (e.g. silently turned "Bonsoir"
                    // into "No sour" in testing), so it must stay off.
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
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
        entries.insert(VocabularyEntry(id: UUID(), text: trimmed, addedAt: .now), at: 0)
        VocabularyStore.save(entries)
        dismiss()
    }
}

#Preview {
    AddVocabularyWordView()
}
