import SwiftUI
import UniformTypeIdentifiers

/// Lets the user pick one or more audio/video files out of the Files app —
/// this is where recordings show up *after* the user has exported/shared them
/// out of Voice Memos (Voice Memos itself has no browsable Files location).
struct VoiceMemoImportView: View {
    @State private var isPickerPresented = false
    @State private var isLanguageSheetPresented = false
    @State private var pendingLanguage: SupportedLanguage = .chineseTraditional
    @State private var pendingShareExtensionFiles: [URL] = []
    @State private var importedRecordings: [ImportedRecording] = ImportedRecordingStore.load()
    @State private var importError: String?

    @AppStorage(AppSettings.enabledLanguagesKey) private var enabledLanguagesRaw: String = ""

    private var enabledLanguages: [SupportedLanguage] {
        let enabled = AppSettings.languages(from: enabledLanguagesRaw)
        return SupportedLanguage.allCases.filter { enabled.contains($0) }
    }

    // Voice Memos exports as .m4a. We also accept mp3 and mp4 (e.g. a video
    // lesson recording) since the user may be pulling audio from elsewhere too.
    private let acceptedTypes: [UTType] = [
        .mpeg4Audio,                      // .m4a — what Voice Memos actually produces
        UTType(filenameExtension: "mp3") ?? .audio,
        .mpeg4Movie                       // .mp4 — in case speech is embedded in video
    ]

    var body: some View {
        NavigationStack {
            List {
                if importedRecordings.isEmpty {
                    ContentUnavailableView(
                        "No recordings yet",
                        systemImage: "waveform",
                        description: Text("Import from Voice Memos (Share → your app), or pick a file below.")
                    )
                }
                ForEach(importedRecordings) { recording in
                    NavigationLink(value: recording) {
                        VStack(alignment: .leading) {
                            Text(recording.originalFilename).font(.headline)
                            Text("\(recording.language.displayName) · \(recording.importedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Audio Samples")
            .navigationDestination(for: ImportedRecording.self) { recording in
                TranscriptionRunnerView(recording: recording)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        pendingShareExtensionFiles = []
                        presentLanguageSheet()
                    } label: {
                        Label("Import from Files", systemImage: "folder.badge.plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $isPickerPresented,
                allowedContentTypes: acceptedTypes,
                allowsMultipleSelection: true
            ) { result in
                handlePickerResult(result, language: pendingLanguage)
            }
            .sheet(isPresented: $isLanguageSheetPresented) {
                languageSelectionSheet
            }
            .task {
                // Anything the Share Extension dropped into the shared App
                // Group container since we last launched — ask which language
                // it's in before copying it into the app, same as Files import.
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
            .onChange(of: importedRecordings) { _, newValue in
                ImportedRecordingStore.save(newValue)
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
                            importedRecordings += SharedContainer.commitPendingFiles(
                                pendingShareExtensionFiles, language: pendingLanguage
                            )
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
                    importedRecordings.append(copy)
                } catch {
                    importError = error.localizedDescription
                }
            }
        }
    }
}
