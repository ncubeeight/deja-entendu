import SwiftUI

/// End-to-end screen: takes an ImportedRecording (from either import path),
/// lets the user pick which language it's spoken in, runs it through the
/// transcriber for that language, then generates pinyin (Chinese only,
/// deterministic) and study notes (on-device LLM, best-effort).
struct TranscriptionRunnerView: View {
    let recording: ImportedRecording

    @State private var selectedLanguage: SupportedLanguage = .chineseTaiwan
    @State private var status: Status = .idle

    enum Status {
        case idle
        case transcribing(SupportedLanguage)
        case transcribed(TranscriptionResult, language: SupportedLanguage, pinyin: String?)
        case notesReady(TranscriptionResult, language: SupportedLanguage, pinyin: String?, notes: StudyNotes)
        case notesUnavailable(TranscriptionResult, language: SupportedLanguage, pinyin: String?, reason: String)
        case failed(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch status {
                case .idle:
                    languagePicker
                    Button("Transcribe") {
                        Task { await runPipeline() }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                case .transcribing(let language):
                    ProgressView("Transcribing (\(language.displayName))…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)

                case .transcribed(let result, _, let pinyin):
                    transcriptBlock(result: result, pinyin: pinyin)
                    ProgressView("Generating study notes…")

                case .notesReady(let result, let language, let pinyin, let notes):
                    transcriptBlock(result: result, pinyin: pinyin)
                    studyNotesBlock(notes, language: language)

                case .notesUnavailable(let result, _, let pinyin, let reason):
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
    }

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spoken language").font(.headline)
            Picker("Spoken language", selection: $selectedLanguage) {
                ForEach(SupportedLanguage.allCases, id: \.self) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private func transcriptBlock(result: TranscriptionResult, pinyin: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcript").font(.headline)
            Text(result.fullText)
            if let pinyin {
                Text(pinyin)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func studyNotesBlock(_ notes: StudyNotes, language: SupportedLanguage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Translation").font(.headline)
            Text(notes.englishTranslation)

            Text("Key Vocabulary").font(.headline).padding(.top, 4)
            ForEach(notes.keyVocabulary, id: \.self) { word in
                if language.isChinese {
                    Text("• \(word)  —  \(PinyinConverter.pinyinWithToneMarks(for: word))")
                } else {
                    Text("• \(word)")
                }
            }

            Text("Note").font(.headline).padding(.top, 4)
            Text(notes.grammarNote)
        }
    }

    private func runPipeline() async {
        let language = selectedLanguage
        status = .transcribing(language)
        do {
            let transcriber = SpeechTranscriberService(language: language)
            let result = try await transcriber.transcribe(fileAt: recording.localURL)
            let pinyin = language.isChinese ? PinyinConverter.pinyinWithToneMarks(for: result.fullText) : nil
            status = .transcribed(result, language: language, pinyin: pinyin)

            do {
                let notes = try await StudyNoteGenerator.generateNotes(forTranscript: result.fullText, language: language)
                status = .notesReady(result, language: language, pinyin: pinyin, notes: notes)
            } catch {
                status = .notesUnavailable(result, language: language, pinyin: pinyin, reason: error.localizedDescription)
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}
