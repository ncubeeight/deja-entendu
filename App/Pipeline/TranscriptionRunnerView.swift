import SwiftUI

/// End-to-end screen: takes an ImportedRecording (from either import path),
/// runs it through the Taiwanese Mandarin transcriber, then generates
/// pinyin (deterministic) and study notes (on-device LLM, best-effort).
struct TranscriptionRunnerView: View {
    let recording: ImportedRecording

    @State private var status: Status = .idle
    private let transcriber = MandarinTranscriber()

    enum Status {
        case idle
        case transcribing
        case transcribed(TranscriptionResult, pinyin: String)
        case notesReady(TranscriptionResult, pinyin: String, notes: StudyNotes)
        case notesUnavailable(TranscriptionResult, pinyin: String, reason: String)
        case failed(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch status {
                case .idle, .transcribing:
                    ProgressView(status.isTranscribing ? "Transcribing (Taiwanese Mandarin)…" : "Preparing…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)

                case .transcribed(let result, let pinyin):
                    transcriptBlock(result: result, pinyin: pinyin)
                    ProgressView("Generating study notes…")

                case .notesReady(let result, let pinyin, let notes):
                    transcriptBlock(result: result, pinyin: pinyin)
                    studyNotesBlock(notes)

                case .notesUnavailable(let result, let pinyin, let reason):
                    transcriptBlock(result: result, pinyin: pinyin)
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
    private func transcriptBlock(result: TranscriptionResult, pinyin: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcript").font(.headline)
            Text(result.fullText)
            Text(pinyin)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func studyNotesBlock(_ notes: StudyNotes) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Translation").font(.headline)
            Text(notes.englishTranslation)

            Text("Key Vocabulary").font(.headline).padding(.top, 4)
            ForEach(notes.keyVocabulary, id: \.self) { word in
                Text("• \(word)  —  \(PinyinConverter.pinyinWithToneMarks(for: word))")
            }

            Text("Note").font(.headline).padding(.top, 4)
            Text(notes.grammarNote)
        }
    }

    private func runPipeline() async {
        status = .transcribing
        do {
            let result = try await transcriber.transcribe(fileAt: recording.localURL)
            let pinyin = PinyinConverter.pinyinWithToneMarks(for: result.fullText)
            status = .transcribed(result, pinyin: pinyin)

            do {
                let notes = try await StudyNoteGenerator.generateNotes(forTranscript: result.fullText)
                status = .notesReady(result, pinyin: pinyin, notes: notes)
            } catch {
                status = .notesUnavailable(result, pinyin: pinyin, reason: error.localizedDescription)
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}

private extension TranscriptionRunnerView.Status {
    var isTranscribing: Bool {
        if case .transcribing = self { return true }
        return false
    }
}
