import SwiftUI
import UniformTypeIdentifiers

/// The merged "Samples" tab — audio recordings, pasted/typed text, and
/// OCR'd photos all in one filterable, color-coded list (see SampleKind).
/// Replaces the old audio-only VoiceMemoImportView; its Files-import and
/// Share Extension handling live on here unchanged.
struct SamplesView: View {
    @State private var audioRecordings: [ImportedRecording] = ImportedRecordingStore.load()
    @State private var textSamples: [ImportedTextSample] = ImportedTextSampleStore.load()
    @State private var imageSamples: [ImportedImageSample] = ImportedImageSampleStore.load()

    @State private var filter: SampleFilter = .all

    @State private var isAddDialogPresented = false
    @State private var isTextImportPresented = false
    @State private var isImageImportPresented = false

    // Generated-sample state.
    @State private var isGenerateLanguageSheetPresented = false
    @State private var pendingGenerateLanguage: SupportedLanguage = .chineseTraditional
    @State private var isGeneratingSample = false
    @State private var generateError: String?

    // Audio-specific import state, ported from the old VoiceMemoImportView.
    @State private var isPickerPresented = false
    @State private var isLanguageSheetPresented = false
    @State private var pendingLanguage: SupportedLanguage = .chineseTraditional
    @State private var pendingShareExtensionFiles: [URL] = []
    @State private var importError: String?

    @AppStorage(AppSettings.enabledLanguagesKey) private var enabledLanguagesRaw: String = ""

    private var enabledLanguages: [SupportedLanguage] {
        let enabled = AppSettings.languages(from: enabledLanguagesRaw)
        return SupportedLanguage.allCases.filter { enabled.contains($0) }
    }

    private let acceptedAudioTypes: [UTType] = [
        .mpeg4Audio,
        UTType(filenameExtension: "mp3") ?? .audio,
        .mpeg4Movie
    ]

    private enum SampleFilter: Hashable, CaseIterable {
        case all, audio, text, image

        var label: String {
            switch self {
            case .all: "All"
            case .audio: SampleKind.audio.label
            case .text: SampleKind.text.label
            case .image: SampleKind.image.label
            }
        }

        var kind: SampleKind? {
            switch self {
            case .all: nil
            case .audio: .audio
            case .text: .text
            case .image: .image
            }
        }
    }

    private var allSamples: [AnySample] {
        let combined: [AnySample] =
            audioRecordings.map(AnySample.audio) +
            textSamples.map(AnySample.text) +
            imageSamples.map(AnySample.image)
        return combined.sorted { $0.importedAt > $1.importedAt }
    }

    private var filteredSamples: [AnySample] {
        guard let kind = filter.kind else { return allSamples }
        return allSamples.filter { $0.kind == kind }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredSamples.isEmpty {
                    ContentUnavailableView(
                        "No samples yet",
                        systemImage: "tray",
                        description: Text("Import a recording, add text, or scan a photo below.")
                    )
                }
                ForEach(filteredSamples) { sample in
                    row(for: sample)
                }
            }
            .overlay {
                if isGeneratingSample {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Generating sample…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                Picker("Filter", selection: $filter) {
                    ForEach(SampleFilter.allCases, id: \.self) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .background(.bar)
            }
            .navigationTitle("Samples")
            .navigationDestination(for: AnySample.self) { sample in
                TranscriptionRunnerView(input: sample.runnerInput)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddDialogPresented = true
                    } label: {
                        Label("Add Sample", systemImage: "plus")
                    }
                }
            }
            .confirmationDialog("Add a Sample", isPresented: $isAddDialogPresented, titleVisibility: .visible) {
                Button("Import Recording") {
                    pendingShareExtensionFiles = []
                    presentLanguageSheet()
                }
                Button("Add Text") { isTextImportPresented = true }
                Button("Scan Photo") { isImageImportPresented = true }
                Button("Generate Sample") { presentGenerateLanguageSheet() }
                Button("Cancel", role: .cancel) {}
            }
            .fileImporter(
                isPresented: $isPickerPresented,
                allowedContentTypes: acceptedAudioTypes,
                allowsMultipleSelection: true
            ) { result in
                handlePickerResult(result, language: pendingLanguage)
            }
            .sheet(isPresented: $isLanguageSheetPresented) {
                languageSelectionSheet
            }
            .sheet(isPresented: $isGenerateLanguageSheetPresented) {
                generateLanguageSelectionSheet
            }
            .sheet(isPresented: $isTextImportPresented, onDismiss: {
                textSamples = ImportedTextSampleStore.load()
            }) {
                TextImportView()
            }
            .sheet(isPresented: $isImageImportPresented, onDismiss: {
                imageSamples = ImportedImageSampleStore.load()
            }) {
                ImageImportView()
            }
            .task {
                // Reload every time this tab appears — otherwise a deletion
                // made from Home's "Continue studying" section wouldn't show
                // up here.
                audioRecordings = ImportedRecordingStore.load()
                textSamples = ImportedTextSampleStore.load()
                imageSamples = ImportedImageSampleStore.load()

                let pending = SharedContainer.pendingFiles()
                if !pending.isEmpty {
                    pendingShareExtensionFiles = pending
                    presentLanguageSheet()
                }
            }
            .alert("Import failed", isPresented: .constant(importError != nil), actions: {
                Button("OK") { importError = nil }
            }, message: {
                Text(importError ?? "")
            })
            .alert("Generation failed", isPresented: .constant(generateError != nil), actions: {
                Button("OK") { generateError = nil }
            }, message: {
                Text(generateError ?? "")
            })
        }
    }

    @ViewBuilder
    private func row(for sample: AnySample) -> some View {
        HStack {
            NavigationLink(value: sample) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(sample.kind.tintSoft)
                            .frame(width: 32, height: 32)
                        Image(systemName: sample.kind.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(sample.kind.tint)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sample.title).font(.headline)
                        Text(sample.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button {
                delete(sample)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func delete(_ sample: AnySample) {
        withAnimation {
            switch sample {
            case .audio(let recording):
                audioRecordings.removeAll { $0.id == recording.id }
                try? FileManager.default.removeItem(at: recording.localURL)
                ImportedRecordingStore.save(audioRecordings)
            case .text(let textSample):
                textSamples.removeAll { $0.id == textSample.id }
                ImportedTextSampleStore.save(textSamples)
            case .image(let imageSample):
                imageSamples.removeAll { $0.id == imageSample.id }
                try? FileManager.default.removeItem(at: imageSample.localURL)
                ImportedImageSampleStore.save(imageSamples)
            }
        }
    }

    @ViewBuilder
    private var languageSelectionSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Spoken language", selection: $pendingLanguage) {
                        ForEach(enabledLanguages, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("What language is this recording in?")
                } footer: {
                    Text("Picking the right language up front means transcription runs in that language from the start.")
                }
            }
            .navigationTitle("Choose Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isLanguageSheetPresented = false
                        pendingShareExtensionFiles = []
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        isLanguageSheetPresented = false
                        if pendingShareExtensionFiles.isEmpty {
                            isPickerPresented = true
                        } else {
                            let added = SharedContainer.commitPendingFiles(
                                pendingShareExtensionFiles, language: pendingLanguage
                            )
                            audioRecordings += added
                            ImportedRecordingStore.save(audioRecordings)
                            pendingShareExtensionFiles = []
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func presentLanguageSheet() {
        if !enabledLanguages.contains(pendingLanguage) {
            pendingLanguage = enabledLanguages.first ?? .chineseTraditional
        }
        isLanguageSheetPresented = true
    }

    @ViewBuilder
    private var generateLanguageSelectionSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Language", selection: $pendingGenerateLanguage) {
                        ForEach(enabledLanguages, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("What language would you like the sample in?")
                } footer: {
                    Text("A short, simple practice paragraph will be generated on-device — no recording or file needed.")
                }
            }
            .navigationTitle("Choose Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isGenerateLanguageSheetPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        isGenerateLanguageSheetPresented = false
                        Task { await generateSample() }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func presentGenerateLanguageSheet() {
        if !enabledLanguages.contains(pendingGenerateLanguage) {
            pendingGenerateLanguage = enabledLanguages.first ?? .chineseTraditional
        }
        isGenerateLanguageSheetPresented = true
    }

    private func generateSample() async {
        isGeneratingSample = true
        do {
            let text = try await SampleTextGenerator.generateParagraph(language: pendingGenerateLanguage)
            let sample = ImportedTextSample(id: UUID(), body: text, importedAt: .now, language: pendingGenerateLanguage)
            textSamples.insert(sample, at: 0)
            ImportedTextSampleStore.save(textSamples)
        } catch {
            generateError = error.localizedDescription
        }
        isGeneratingSample = false
    }

    private func handlePickerResult(_ result: Result<[URL], Error>, language: SupportedLanguage) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription

        case .success(let urls):
            for pickedURL in urls {
                do {
                    let copy = try AudioIngestion.copyIntoAppContainer(
                        from: pickedURL,
                        source: .filesImporter,
                        language: language
                    )
                    audioRecordings.append(copy)
                    ImportedRecordingStore.save(audioRecordings)
                } catch {
                    importError = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    SamplesView()
}
