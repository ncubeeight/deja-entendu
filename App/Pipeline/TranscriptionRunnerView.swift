import SwiftUI

/// End-to-end screen: takes an ImportedRecording (from either import path,
/// already tagged with the language the user picked before importing), runs
/// it through the transcriber for that language, then generates study notes
/// (on-device LLM, best-effort). Transcripts stay in the language's original
/// script — no automatic romanization.
struct TranscriptionRunnerView: View {
    let recording: ImportedRecording

    @State private var status: Status = .idle

    enum Status {
        case idle
        case transcribing
        case transcribed(TranscriptionResult)
        case notesReady(TranscriptionResult, notes: StudyNotes)
        case notesUnavailable(TranscriptionResult, reason: String)
        case failed(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch status {
                case .idle, .transcribing:
                    ProgressView("Transcribing (\(recording.language.displayName))…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)

                case .transcribed(let result):
                    transcriptBlock(result: result)
                    ProgressView("Generating study notes…")

                case .notesReady(let result, let notes):
                    transcriptBlock(result: result)
                    studyNotesBlock(notes)

                case .notesUnavailable(let result, let reason):
                    transcriptBlock(result: result)
                    Text("Study notes unavailable: \(reason)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                case .failed(let message):
                    Text(message)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .navigationTitle(recording.originalFilename)
        .task { await runPipeline() }
    }

    @ViewBuilder
    private func transcriptBlock(result: TranscriptionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcript").font(.headline)
            Text("Tap a word to add it to your Vocabulary list.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(
                    Array(TextSegmentation.sentences(in: result.fullText, language: recording.language.nlLanguage).enumerated()),
                    id: \.offset
                ) { _, sentence in
                    FlowLayout(spacing: 4) {
                        ForEach(
                            Array(TextSegmentation.words(in: sentence, language: recording.language.nlLanguage).enumerated()),
                            id: \.offset
                        ) { _, word in
                            TranscriptWordToken(word: word, language: recording.language)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func studyNotesBlock(_ notes: StudyNotes) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Translation").font(.headline)
            Text(notes.englishTranslation)

            Text("Key Vocabulary").font(.headline).padding(.top, 4)
            ForEach(notes.keyVocabulary, id: \.self) { word in
                Text("• \(word)")
            }

            Text("Note").font(.headline).padding(.top, 4)
            Text(notes.grammarNote)
        }
    }

    private func runPipeline() async {
        status = .transcribing
        do {
            let transcriber = SpeechTranscriberService(language: recording.language)
            let result = try await transcriber.transcribe(fileAt: recording.localURL)
            status = .transcribed(result)

            do {
                let notes = try await StudyNoteGenerator.generateNotes(forTranscript: result.fullText, language: recording.language)
                status = .notesReady(result, notes: notes)
            } catch {
                status = .notesUnavailable(result, reason: error.localizedDescription)
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}

private struct TranscriptWordToken: View {
    let word: String
    let language: SupportedLanguage

    @State private var isSelected = false
    @State private var didAdd = false

    var body: some View {
        Text(word)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(
                isSelected ? Color.accentColor.opacity(0.22) : .clear,
                in: RoundedRectangle(cornerRadius: 5)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                isSelected = true
            }
            .popover(isPresented: $isSelected, arrowEdge: .top) {
                popoverContent
                    .presentationCompactAdaptation(.popover)
                    .onDisappear { didAdd = false }
            }
    }

    @ViewBuilder
    private var popoverContent: some View {
        VStack(spacing: 10) {
            Text(word).font(.headline)

            if didAdd {
                Label("Added to Vocabulary", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            } else {
                Button {
                    addToVocabulary()
                } label: {
                    Label("Add to Vocabulary", systemImage: "text.book.closed")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 220)
    }

    private func addToVocabulary() {
        var entries = VocabularyStore.load()
        entries.insert(VocabularyEntry(id: UUID(), text: word, addedAt: .now, language: language), at: 0)
        VocabularyStore.save(entries)
        didAdd = true
    }
}
