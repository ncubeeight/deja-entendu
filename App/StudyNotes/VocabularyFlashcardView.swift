import SwiftUI
import AVFoundation
import UIKit

/// A dedicated page for one vocabulary term: pronunciation, translation, and
/// an example sentence with the term highlighted. Generated on-device the
/// first time this opens, then cached on the entry so reopening it is instant.
struct VocabularyFlashcardView: View {
    let entry: VocabularyEntry

    @State private var status: Status
    @State private var speaker = TextSpeaker()
    @State private var isDictionarySheetPresented = false
    /// Looked up once per card in .task rather than computed in body —
    /// see GlossaryStore.definition(forTerm:language:).
    @State private var customDefinition: String?

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
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Text(entry.text)
                            .font(.system(size: 40, weight: .bold))

                        Button {
                            speaker.speak(entry.text, language: entry.language)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.title2)
                        }
                        .disabled(!isVoiceAvailable)

                        SpeechPaceMenu(font: .title3)
                            .disabled(!isVoiceAvailable)
                    }

                    if !isVoiceAvailable {
                        Text("Spoken pronunciation isn't available for \(entry.language?.displayName ?? "this term") on this device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Shown regardless of loading/ready/failed status — this is
                // the user's own data, not something generation success or
                // failure should gate. Also the main reason this screen
                // stays useful on a device with no on-device model at all:
                // a matching custom entry means there's still something
                // real to show instead of just an error.
                if let customDefinition {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Your Definition", systemImage: "bookmark.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(customDefinition)
                            .font(.title3)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                }

                switch status {
                case .loading:
                    ProgressView("Generating…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)

                case .failed(let reason):
                    VStack(alignment: .leading, spacing: 12) {
                        Text(reason)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        // On-device generation needs Apple Intelligence
                        // (iPhone 15 Pro/16/17 or later) — this is the
                        // fallback for everyone else: the system Dictionary
                        // app's own lookup, which has shipped since iOS 5
                        // and needs nothing beyond a matching dictionary the
                        // user has installed (Settings > General >
                        // Dictionary). It's a different, plainer UI than the
                        // rest of this screen — Apple's own sheet, not
                        // something we can restyle to match — but it beats
                        // a dead end for older devices.
                        if UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: entry.text) {
                            Button {
                                isDictionarySheetPresented = true
                            } label: {
                                Label("Look Up in Dictionary", systemImage: "character.book.closed")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                case .ready(let details):
                    detailsBlock(details)
                }
            }
            .padding()
        }
        .navigationTitle("Flashcard")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isDictionarySheetPresented) {
            DictionaryLookupView(term: entry.text)
                .ignoresSafeArea()
        }
        .task {
            // Separate from the generation task so the first lookup after
            // launch (which builds the glossary index) doesn't hold it up.
            let term = entry.text
            let language = entry.language
            customDefinition = await Task.detached(priority: .userInitiated) {
                GlossaryStore.definition(forTerm: term, language: language)
            }.value
        }
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
                HStack(spacing: 8) {
                    Text("Example").font(.caption).foregroundStyle(.secondary)
                    Button {
                        speaker.speak(details.exampleSentence, language: entry.language)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                    }
                    .disabled(!isVoiceAvailable)

                    SpeechPaceMenu(font: .caption)
                        .disabled(!isVoiceAvailable)
                }
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

    private var isVoiceAvailable: Bool {
        TextSpeaker.isVoiceAvailable(for: entry.language)
    }

    private func generate() async {
        status = .loading
        do {
            let details = try await FlashcardGenerator.generateDetails(forTerm: entry.text, language: entry.language)
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

/// Wraps the system Dictionary app's own lookup UI (UIReferenceLibraryViewController)
/// so it can be presented as a SwiftUI sheet — no on-device LLM required, so
/// this works on any device, including ones without Apple Intelligence.
private struct DictionaryLookupView: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ uiViewController: UIReferenceLibraryViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        VocabularyFlashcardView(entry: VocabularyEntry(id: UUID(), text: "Bonjour", addedAt: .now))
    }
}
