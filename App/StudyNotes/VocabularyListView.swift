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
                HStack {
                    NavigationLink(value: entry) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.text).font(.body)
                            Text(entry.addedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        delete(entry)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Vocabulary")
        .navigationDestination(for: VocabularyEntry.self) { entry in
            VocabularyFlashcardView(entry: entry)
        }
        .task {
            // Pick up anything added elsewhere (the transcript's "Add to
            // Vocabulary" button, the Home screen's manual-add sheet) since
            // this view last loaded — those write straight to the store,
            // not through the Share Extension inbox below.
            entries = VocabularyStore.load()

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

    private func delete(_ entry: VocabularyEntry) {
        withAnimation {
            entries.removeAll { $0.id == entry.id }
        }
        VocabularyStore.save(entries)
    }
}

#Preview {
    NavigationStack {
        VocabularyListView()
    }
}
