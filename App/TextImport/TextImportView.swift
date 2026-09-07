import SwiftUI
import UniformTypeIdentifiers
import PDFKit

/// A lightweight manual entry point for a text sample — the text-import
/// counterpart to AddVocabularyWordView, but for a whole passage rather
/// than a single word. Saves straight into ImportedTextSampleStore and
/// dismisses, same self-contained pattern.
struct TextImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var body_: String = ""
    @State private var language: SupportedLanguage = .chineseTraditional
    @State private var isFileImporterPresented = false
    @State private var importError: String?

    @AppStorage(AppSettings.enabledLanguagesKey) private var enabledLanguagesRaw: String = ""

    private var enabledLanguages: [SupportedLanguage] {
        let enabled = AppSettings.languages(from: enabledLanguagesRaw)
        return SupportedLanguage.allCases.filter { enabled.contains($0) }
    }

    private let acceptedTypes: [UTType] = [.pdf, .plainText, .utf8PlainText]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        isFileImporterPresented = true
                    } label: {
                        Label("Select PDF or Text File", systemImage: "doc.badge.plus")
                    }
                } footer: {
                    Text("Text is extracted and filled in below, so you can review or edit it before saving.")
                }

                Section {
                    TextEditor(text: $body_)
                        .frame(minHeight: 160)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Text")
                } footer: {
                    Text("Paste or type a passage in the language you're studying.")
                }

                Picker("Language", selection: $language) {
                    ForEach(enabledLanguages, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            }
            .onAppear {
                if !enabledLanguages.contains(language) {
                    language = enabledLanguages.first ?? .chineseTraditional
                }
            }
            .navigationTitle("Add Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(body_.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: acceptedTypes) { result in
                handleFileImport(result)
            }
            .alert("Couldn't import that file", isPresented: .constant(importError != nil), actions: {
                Button("OK") { importError = nil }
            }, message: {
                Text(importError ?? "")
            })
        }
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription

        case .success(let url):
            // .fileImporter hands back a security-scoped URL — must bracket
            // access the same way AudioIngestion does for picked audio files.
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }

            if url.pathExtension.lowercased() == "pdf" {
                guard
                    let document = PDFDocument(url: url),
                    let text = document.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !text.isEmpty
                else {
                    importError = "Couldn't find any text in that PDF — it may be a scanned document with no text layer."
                    return
                }
                body_ = text
            } else {
                guard
                    let text = try? String(contentsOf: url, encoding: .utf8),
                    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    importError = "Couldn't read that file as text."
                    return
                }
                body_ = text
            }
        }
    }

    private func save() {
        let trimmed = body_.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var entries = ImportedTextSampleStore.load()
        entries.insert(ImportedTextSample(id: UUID(), body: trimmed, importedAt: .now, language: language), at: 0)
        ImportedTextSampleStore.save(entries)
        dismiss()
    }
}

#Preview {
    TextImportView()
}
