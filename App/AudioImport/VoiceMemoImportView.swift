import SwiftUI
import UniformTypeIdentifiers

/// Lets the user pick one or more audio/video files out of the Files app —
/// this is where recordings show up *after* the user has exported/shared them
/// out of Voice Memos (Voice Memos itself has no browsable Files location).
struct VoiceMemoImportView: View {
    @State private var isPickerPresented = false
    @State private var importedRecordings: [ImportedRecording] = []
    @State private var importError: String?

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
                            Text(recording.importedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Recordings")
            .navigationDestination(for: ImportedRecording.self) { recording in
                TranscriptionRunnerView(recording: recording)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        IrohaExplorerView()
                    } label: {
                        Label("Call with Mom", systemImage: "character.book.closed")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPickerPresented = true
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
                handlePickerResult(result)
            }
            .task {
                // Pick up anything the Share Extension dropped into the shared
                // App Group container since we last launched.
                importedRecordings += SharedContainer.drainPendingShareExtensionFiles()
            }
            .alert("Import failed", isPresented: .constant(importError != nil), actions: {
                Button("OK") { importError = nil }
            }, message: {
                Text(importError ?? "")
            })
        }
    }

    private func handlePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription

        case .success(let urls):
            for pickedURL in urls {
                do {
                    let copy = try AudioIngestion.copyIntoAppContainer(
                        from: pickedURL,
                        source: .filesImporter
                    )
                    importedRecordings.append(copy)
                } catch {
                    importError = error.localizedDescription
                }
            }
        }
    }
}
