import SwiftUI

/// What TranscriptionRunnerView needs to run the shared transcript →
/// vocabulary pipeline. Audio needs an actual transcription pass first;
/// text and OCR'd image samples already have their text ready and skip
/// straight to the shared part (segmentation, tap-to-add-vocabulary, study
/// notes).
enum SampleInput {
    case audio(ImportedRecording)
    case readyText(title: String, text: String, language: SupportedLanguage)

    var title: String {
        switch self {
        case .audio(let recording): recording.originalFilename
        case .readyText(let title, _, _): title
        }
    }

    var language: SupportedLanguage {
        switch self {
        case .audio(let recording): recording.language
        case .readyText(_, _, let language): language
        }
    }
}

/// End-to-end screen: takes a SampleInput (audio, ready to transcribe; or
/// text/image, already resolved to plain text), runs whatever's needed to
/// get a transcript, then generates study notes (on-device LLM,
/// best-effort). Transcripts stay in the language's original script — no
/// automatic romanization.
struct TranscriptionRunnerView: View {
    let input: SampleInput

    @State private var status: Status = .idle
    @State private var flashcardEntry: VocabularyEntry?

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
                    ProgressView(loadingLabel)
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
        .navigationTitle(input.title)
        .navigationDestination(item: $flashcardEntry) { entry in
            VocabularyFlashcardView(entry: entry)
        }
        .task { await runPipeline() }
    }

    private var loadingLabel: String {
        switch input {
        case .audio: "Transcribing (\(input.language.displayName))…"
        case .readyText: "Preparing (\(input.language.displayName))…"
        }
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
                    Array(TextSegmentation.sentences(in: result.fullText, language: input.language.nlLanguage).enumerated()),
                    id: \.offset
                ) { _, sentence in
                    FlowLayout(spacing: 4) {
                        ForEach(
                            Array(TextSegmentation.words(in: sentence, language: input.language.nlLanguage).enumerated()),
                            id: \.offset
                        ) { index, word in
                            TranscriptWordToken(
                                word: word,
                                language: input.language,
                                background: AppTheme.rainbow[index % AppTheme.rainbow.count]
                            ) { entry in
                                flashcardEntry = entry
                            }
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
        }
    }

    private func runPipeline() async {
        switch input {
        case .audio(let recording):
            status = .transcribing
            do {
                let transcriber = SpeechTranscriberService(language: recording.language)
                let result = try await transcriber.transcribe(fileAt: recording.localURL)
                status = .transcribed(result)
                await generateNotes(for: result)
            } catch {
                status = .failed(error.localizedDescription)
            }

        case .readyText(_, let text, _):
            let result = TranscriptionResult(fullText: text, segments: [])
            status = .transcribed(result)
            await generateNotes(for: result)
        }
    }

    private func generateNotes(for result: TranscriptionResult) async {
        do {
            let notes = try await StudyNoteGenerator.generateNotes(forTranscript: result.fullText, language: input.language)
            status = .notesReady(result, notes: notes)
        } catch {
            status = .notesUnavailable(result, reason: error.localizedDescription)
        }
    }
}

private struct TranscriptWordToken: View {
    let word: String
    let language: SupportedLanguage
    let background: Color
    let onSelectEntry: (VocabularyEntry) -> Void

    @State private var isSelected = false
    @State private var addedEntry: VocabularyEntry?
    @State private var glossState: GlossState = .loading

    private enum GlossState {
        case loading
        case ready(String)
        case failed
    }

    var body: some View {
        Text(word)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(
                isSelected ? Color.accentColor.opacity(0.22) : background,
                in: RoundedRectangle(cornerRadius: 5)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                isSelected = true
            }
            .popover(isPresented: $isSelected, arrowEdge: .top) {
                popoverContent
                    .presentationCompactAdaptation(.popover)
                    .onDisappear { addedEntry = nil }
                    .task {
                        guard case .loading = glossState else { return }
                        await loadGloss()
                    }
            }
    }

    @ViewBuilder
    private var popoverContent: some View {
        VStack(spacing: 10) {
            Text(word).font(.headline)

            switch glossState {
            case .loading:
                ProgressView()
                    .controlSize(.small)
            case .ready(let gloss):
                Text(gloss)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .failed:
                EmptyView()
            }

            if let addedEntry {
                Label("Added to Vocabulary", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)

                // Navigating straight from here (rather than via a
                // NavigationLink inside this popover) avoids the popover's
                // separate presentation context, which doesn't reliably push
                // onto the presenting view's NavigationStack — dismiss first,
                // then hand the entry back to the parent to navigate.
                Button {
                    isSelected = false
                    onSelectEntry(addedEntry)
                } label: {
                    Label("View Flashcard", systemImage: "rectangle.on.rectangle")
                }
                .buttonStyle(.bordered)
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

    private func loadGloss() async {
        do {
            let gloss = try await WordGlossGenerator.gloss(forWord: word, language: language)
            glossState = .ready(gloss)
        } catch {
            glossState = .failed
        }
    }

    private func addToVocabulary() {
        var entries = VocabularyStore.load()
        let entry = VocabularyEntry(id: UUID(), text: word, addedAt: .now, language: language)
        entries.insert(entry, at: 0)
        VocabularyStore.save(entries)
        addedEntry = entry
    }
}
