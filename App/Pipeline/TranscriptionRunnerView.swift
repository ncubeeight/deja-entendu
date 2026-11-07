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
        case .audio(let recording): recording.displayTitle
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
    @State private var speaker = TextSpeaker()

    // Text-selection mode. The transcript normally renders as individual
    // tappable word tokens (tap-to-add-vocabulary), which native text
    // selection can't span — so a long-press offers "Select" / "Select
    // All", which swaps the page over to one plain selectable text view
    // until the user taps Done.
    @State private var isSelecting = false
    @State private var selectAllRequest = 0
    @State private var selectedText = ""
    @State private var didCopy = false

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
                if isSelecting, currentResult != nil {
                    selectionBlock
                    if case .transcribed = status {
                        ProgressView("Generating study notes…")
                    }
                } else {
                    switch status {
                    case .idle, .transcribing:
                        ProgressView(loadingLabel)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)

                    case .transcribed(let result):
                        transcriptBlock(result: result)
                            .selectionContextMenu(preview: result.fullText, title: input.title, onSelect: enterSelection)
                        ProgressView("Generating study notes…")

                    case .notesReady(let result, let notes):
                        VStack(alignment: .leading, spacing: 16) {
                            transcriptBlock(result: result)
                            studyNotesBlock(notes)
                        }
                        .selectionContextMenu(preview: result.fullText, title: input.title, onSelect: enterSelection)

                    case .notesUnavailable(let result, let reason):
                        transcriptBlock(result: result)
                            .selectionContextMenu(preview: result.fullText, title: input.title, onSelect: enterSelection)
                        Text("Study notes unavailable: \(reason)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                    case .failed(let message):
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(input.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Mail, Messages, Notes, Files, etc. all come from the
                // system share sheet; subject is what Mail uses as the
                // subject line.
                ShareLink(
                    item: shareText,
                    subject: Text(input.title),
                    preview: SharePreview(input.title)
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(currentResult == nil)
                .accessibilityLabel("Share Sample")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                selectionActionBar
            }
        }
        .navigationDestination(item: $flashcardEntry) { entry in
            VocabularyFlashcardView(entry: entry)
        }
        .task { await runPipeline() }
        .onDisappear { speaker.stop() }
    }

    // MARK: - Selection & sharing

    private var currentResult: TranscriptionResult? {
        switch status {
        case .transcribed(let result), .notesReady(let result, _), .notesUnavailable(let result, _):
            result
        case .idle, .transcribing, .failed:
            nil
        }
    }

    private var currentNotes: StudyNotes? {
        if case .notesReady(_, let notes) = status { notes } else { nil }
    }

    /// Transcript / Translation / Key Vocabulary as (heading, body) pairs —
    /// shared by the selectable view and the exported share text so the
    /// two always match.
    private var exportSections: [(heading: String, body: String)] {
        guard let result = currentResult else { return [] }
        var sections = [(heading: "Transcript", body: result.fullText)]
        if let notes = currentNotes {
            sections.append((heading: "Translation", body: notes.englishTranslation))
            if !notes.keyVocabulary.isEmpty {
                sections.append((
                    heading: "Key Vocabulary",
                    body: notes.keyVocabulary.map { "• \($0)" }.joined(separator: "\n")
                ))
            }
        }
        return sections
    }

    private var shareText: String {
        let header = "\(input.title)\nLanguage: \(input.language.displayName)"
        let body = exportSections.map { "\($0.heading)\n\($0.body)" }
        return ([header] + body).joined(separator: "\n\n")
    }

    private func enterSelection(selectAll: Bool) {
        speaker.stop()
        selectedText = ""
        // A fresh SelectableTextView starts its coordinator at 0, so
        // resetting here keeps an old request from re-firing.
        selectAllRequest = selectAll ? 1 : 0
        isSelecting = true
    }

    @ViewBuilder
    private var selectionBlock: some View {
        Text("Drag to select text, or long-press a word. Tap Done to go back to tapping words for vocabulary.")
            .font(.caption)
            .foregroundStyle(.secondary)
        SelectableTextView(
            sections: exportSections,
            selectAllRequest: selectAllRequest,
            selectedText: $selectedText
        )
    }

    private var selectionActionBar: some View {
        HStack {
            Button("Done") {
                isSelecting = false
                selectedText = ""
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Select All") { selectAllRequest += 1 }
                .buttonStyle(.bordered)

            Button {
                UIPasteboard.general.string = selectedText
                didCopy = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    didCopy = false
                }
            } label: {
                Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedText.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
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
            HStack(spacing: 12) {
                Text("Transcript").font(.headline)
                Button {
                    if speaker.isSpeaking {
                        speaker.stop()
                    } else {
                        speaker.speak(result.fullText, language: input.language)
                    }
                } label: {
                    Image(systemName: speaker.isSpeaking ? "stop.circle.fill" : "speaker.wave.2.fill")
                        .font(.title3)
                }
                .disabled(!TextSpeaker.isVoiceAvailable(for: input.language))
                .accessibilityLabel(speaker.isSpeaking ? "Stop speaking" : "Speak transcript")

                SpeechPaceMenu(font: .body)
                    .disabled(!TextSpeaker.isVoiceAvailable(for: input.language))
            }
            if !TextSpeaker.isVoiceAvailable(for: input.language) {
                Text("Spoken audio isn't available for \(input.language.displayName) on this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
    @State private var speaker = TextSpeaker()

    private enum GlossState {
        case loading
        case ready(String)
        case failed
    }

    var body: some View {
        Text(word)
            // The highlight backgrounds (AppTheme.rainbow, and the coral
            // selection tint below) are fixed light pastels regardless of
            // light/dark mode — leaving this at the default .primary text
            // color meant it turned white in dark mode, unreadable against
            // those same light backgrounds. AppTheme.ink is a fixed dark
            // color, not one that flips with the system scheme, so it stays
            // legible against these highlights either way.
            .foregroundStyle(AppTheme.ink)
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
                    .onDisappear {
                        addedEntry = nil
                        speaker.stop()
                    }
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

            if TextSpeaker.isVoiceAvailable(for: language) {
                HStack(spacing: 10) {
                    Button {
                        if speaker.isSpeaking {
                            speaker.stop()
                        } else {
                            speaker.speak(word, language: language)
                        }
                    } label: {
                        Label(
                            speaker.isSpeaking ? "Stop" : "Pronounce This",
                            systemImage: speaker.isSpeaking ? "stop.circle.fill" : "speaker.wave.2.fill"
                        )
                    }
                    .buttonStyle(.bordered)

                    SpeechPaceMenu(font: .body)
                }
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
        if NavajoSupport.isNavajo(language), let gloss = await NavajoSupport.gloss(forWord: word) {
            glossState = .ready(gloss)
            return
        }
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

// MARK: - Long-press "Select / Select All" menu

private extension View {
    /// Long-press anywhere on the sample's content offers Select / Select
    /// All. A small custom preview stands in for the lifted view — the
    /// default would scale the whole (possibly very long) transcript down
    /// into the menu. Word-token taps are unaffected.
    func selectionContextMenu(
        preview: String,
        title: String,
        onSelect: @escaping (_ selectAll: Bool) -> Void
    ) -> some View {
        contextMenu {
            Button {
                onSelect(false)
            } label: {
                Label("Select", systemImage: "selection.pin.in.out")
            }
            Button {
                onSelect(true)
            } label: {
                Label("Select All", systemImage: "text.justify.left")
            }
        } preview: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            .padding()
            .frame(width: 300, alignment: .leading)
        }
    }
}

// MARK: - Selectable text

/// SwiftUI's Text only supports copying a whole Text on iOS, not selecting
/// part of it, so selection mode uses a non-editable UITextView — which
/// brings the native selection handles and Copy / Look Up / Translate /
/// Share edit menu with it.
private struct SelectableTextView: UIViewRepresentable {
    let sections: [(heading: String, body: String)]
    /// Bumped by the parent to request "select everything".
    let selectAllRequest: Int
    @Binding var selectedText: String

    func makeCoordinator() -> Coordinator { Coordinator(selectedText: $selectedText) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.selectedText = $selectedText
        let attributed = Self.attributedText(for: sections)
        if textView.attributedText != attributed {
            textView.attributedText = attributed
        }
        if selectAllRequest != context.coordinator.lastSelectAllRequest {
            context.coordinator.lastSelectAllRequest = selectAllRequest
            // Deferred so the view is in a window and can take focus.
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
                textView.selectedRange = NSRange(location: 0, length: textView.attributedText.length)
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitted.height))
    }

    private static func attributedText(for sections: [(heading: String, body: String)]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .headline),
            .foregroundColor: UIColor.label
        ]
        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineSpacing = 4
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label,
            .paragraphStyle: bodyStyle
        ]
        for (index, section) in sections.enumerated() {
            if index > 0 { result.append(NSAttributedString(string: "\n\n", attributes: bodyAttributes)) }
            result.append(NSAttributedString(string: section.heading + "\n", attributes: headingAttributes))
            result.append(NSAttributedString(string: section.body, attributes: bodyAttributes))
        }
        return result
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var selectedText: Binding<String>
        var lastSelectAllRequest = 0

        init(selectedText: Binding<String>) {
            self.selectedText = selectedText
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            let range = textView.selectedRange
            let text = range.length > 0
                ? (textView.text as NSString).substring(with: range)
                : ""
            // Delegate callbacks can land mid view-update.
            DispatchQueue.main.async { self.selectedText.wrappedValue = text }
        }
    }
}
