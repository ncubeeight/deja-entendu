import SwiftUI

/// Terms shared in from other apps (e.g. Translate) via the Share
/// Extension's plain-text path, plus anything added manually later.
struct VocabularyListView: View {
    @State private var entries: [VocabularyEntry] = VocabularyStore.load()

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No vocabulary yet",
                    systemImage: "text.book.closed",
                    description: Text("Share a word or phrase from Translate (or any app) into Déjà Entendu to add it here.")
                )
            }
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.text).font(.body)
                    Text(entry.addedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Vocabulary")
        .task {
            let newTexts = SharedContainer.drainPendingVocabularyTexts()
            guard !newTexts.isEmpty else { return }
            let newEntries = newTexts.map { VocabularyEntry(id: UUID(), text: $0, addedAt: .now) }
            entries = newEntries + entries
            VocabularyStore.save(entries)
        }
    }

    private func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        VocabularyStore.save(entries)
    }
}

#Preview {
    NavigationStack {
        VocabularyListView()
    }
}
