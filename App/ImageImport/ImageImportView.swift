import SwiftUI
import PhotosUI

/// Photo → text import: pick a photo from the library, run it through
/// on-device OCR (ImageIngestion), then let the user correct any
/// recognition mistakes before saving — OCR on a photographed sign or menu
/// won't always be perfect, so review is required, not optional.
struct ImageImportView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var language: SupportedLanguage = .chineseTraditional
    @State private var pickerItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var ingestedSample: ImportedImageSample?
    @State private var editableText: String = ""
    @State private var importError: String?

    @AppStorage(AppSettings.enabledLanguagesKey) private var enabledLanguagesRaw: String = ""

    private var enabledLanguages: [SupportedLanguage] {
        let enabled = AppSettings.languages(from: enabledLanguagesRaw)
        return SupportedLanguage.allCases.filter { enabled.contains($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Language", selection: $language) {
                    ForEach(enabledLanguages, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .disabled(ingestedSample != nil)

                Section {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(
                            ingestedSample == nil ? "Choose Photo" : "Choose a Different Photo",
                            systemImage: "photo.badge.plus"
                        )
                    }
                }

                if isProcessing {
                    ProgressView("Recognizing text…")
                }

                if ingestedSample != nil {
                    Section {
                        TextEditor(text: $editableText)
                            .frame(minHeight: 160)
                    } header: {
                        Text("Recognized text")
                    } footer: {
                        Text("Correct anything the scan got wrong before saving.")
                    }
                }
            }
            .onAppear {
                if !enabledLanguages.contains(language) {
                    language = enabledLanguages.first ?? .chineseTraditional
                }
            }
            .onChange(of: pickerItem) { _, newValue in
                guard let newValue else { return }
                Task { await processPickedItem(newValue) }
            }
            .navigationTitle("Scan Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(ingestedSample == nil || editableText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Import failed", isPresented: .constant(importError != nil), actions: {
                Button("OK") { importError = nil }
            }, message: {
                Text(importError ?? "")
            })
        }
    }

    private func processPickedItem(_ item: PhotosPickerItem) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw ImageIngestionError.couldNotDecodeImage
            }
            let sample = try ImageIngestion.copyAndRecognizeText(
                from: data,
                suggestedFilename: "Scanned Photo",
                language: language
            )
            ingestedSample = sample
            editableText = sample.recognizedText
        } catch {
            importError = error.localizedDescription
        }
    }

    private func save() {
        guard let ingestedSample else { return }
        let trimmed = editableText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let finalSample = ImportedImageSample(
            id: ingestedSample.id,
            originalFilename: ingestedSample.originalFilename,
            localURL: ingestedSample.localURL,
            recognizedText: trimmed,
            importedAt: ingestedSample.importedAt,
            language: ingestedSample.language
        )

        var entries = ImportedImageSampleStore.load()
        entries.insert(finalSample, at: 0)
        ImportedImageSampleStore.save(entries)
        dismiss()
    }
}

#Preview {
    ImageImportView()
}
