import SwiftUI

/// A dedicated page for one vocabulary term: pronunciation, translation, and
/// an example sentence with the term highlighted. Generated on-device the
/// first time this opens, then cached on the entry so reopening it is instant.
struct VocabularyFlashcardView: View {
    let entry: VocabularyEntry

    @State private var status: Status

    private enum Status {
        case loading
        case ready(FlashcardDetails)
        case failed(String)
    }

    init(entry: VocabularyEntry) {
        self.entry = entry
        if let pronunciation = entry.pronunciation,
           let translation = entry.translation,
           let exampleSentence = entry.exampleSentence,
           let exampleTranslation = entry.exampleTranslation {
            _status = State(initialValue: .ready(FlashcardDetails(
                pronunciation: pronunciation,
                translation: translation,
                exampleSentence: exampleSentence,
                exampleTranslation: exampleTranslation
            )))
        } else {
            _status = State(initialValue: .loading)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(entry.text)
                    .font(.system(size: 40, weight: .bold))

                switch status {
                case .loading:
                    ProgressView("Generating…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)

                case .failed(let reason):
                    Text(reason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                case .ready(let details):
                    detailsBlock(details)
                }
            }
            .padding()
        }
        .navigationTitle("Flashcard")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !entry.hasFlashcardDetails else { return }
            await generate()
        }
    }

    @ViewBuilder
    private func detailsBlock(_ details: FlashcardDetails) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pronunciation").font(.caption).foregroundStyle(.secondary)
                Text(details.pronunciation).font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Translation").font(.caption).foregroundStyle(.secondary)
                Text(details.translation).font(.title3)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Example").font(.caption).foregroundStyle(.secondary)
                Text(highlighted(details.exampleSentence, term: entry.text))
                    .font(.body)
                Text(details.exampleTranslation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Label("On-device", systemImage: "sparkles")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Bolds/colors the first case-insensitive occurrence of `term` inside
    /// `sentence`. If the model conjugated or otherwise didn't reuse the
    /// term verbatim, this just falls back to plain, unhighlighted text.
    private func highlighted(_ sentence: String, term: String) -> AttributedString {
        var attributed = AttributedString(sentence)
        guard
            !term.isEmpty,
            let range = sentence.range(of: term, options: [.caseInsensitive])
        else { return attributed }

        if let attributedRange = Range(range, in: attributed) {
            attributed[attributedRange].font = .body.bold()
            attributed[attributedRange].foregroundColor = .accentColor
        }
        return attributed
    }

    private func generate() async {
        status = .loading
        do {
            let details = try await FlashcardGenerator.generateDetails(forTerm: entry.text)
            status = .ready(details)

            var entries = VocabularyStore.load()
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[index].pronunciation = details.pronunciation
                entries[index].translation = details.translation
                entries[index].exampleSentence = details.exampleSentence
                entries[index].exampleTranslation = details.exampleTranslation
                VocabularyStore.save(entries)
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}

#Preview {
    NavigationStack {
        VocabularyFlashcardView(entry: VocabularyEntry(id: UUID(), text: "Bonjour", addedAt: .now))
    }
}
