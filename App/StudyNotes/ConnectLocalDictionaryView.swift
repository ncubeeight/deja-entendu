import SwiftUI
import UniformTypeIdentifiers
import PDFKit

/// Connects a dictionary file the user already owns — downloaded or
/// exported from somewhere else, picked from Files/iCloud Drive/On My
/// iPhone — as an addition to the glossary, rather than typing each term
/// in by hand (AddGlossaryEntryView) or downloading one of Apple's own
/// Translate packs (DictionaryLanguagePacksSection). Any number of
/// dictionaries can be connected; each keeps its own terms (tagged via
/// GlossaryEntry.dictionaryID) so it can be browsed or disconnected on its
/// own from the Custom Glossary page. The connected dictionary's language
/// also becomes the default pre-selected language for new Samples (see
/// AppSettings.preferredDefaultLanguage). If the file is in a language the
/// app doesn't list — Navajo, say — choosing "Other language…" adds it as
/// a new language that then appears in Settings' "Languages shown on
/// import" like any other, where it can be toggled on and off.
///
/// Understands two source layouts:
/// - A plain two-column word list (term/definition per line, separated by
///   a tab, comma, or dash) — typical of a simple word-list export.
/// - A prose dictionary PDF or text file laid out as one entry per line —
///   "headword (variant) [etymology] : definition." — where the
///   definition may wrap across several lines until the next headword.
///   This is the layout of real compiled dictionaries (verified against a
///   Mauritian-English Dictionary PDF export).
struct ConnectLocalDictionaryView: View {
    @Environment(\.dismiss) private var dismiss

    private enum LanguageChoice: Hashable {
        case listed(SupportedLanguage)
        case other
    }

    @State private var choice: LanguageChoice = .listed(.chineseTraditional)
    @State private var otherLanguageName = ""
    @State private var isFileImporterPresented = false
    @State private var fileName: String?
    @State private var pendingBookmarkData: Data?
    @State private var isParsing = false
    @State private var parsedEntries: [ParsedEntry] = []
    @State private var duplicateCount = 0
    @State private var importError: String?

    @AppStorage(AppSettings.enabledLanguagesKey) private var enabledLanguagesRaw: String = ""

    private var enabledLanguages: [SupportedLanguage] {
        let enabled = AppSettings.languages(from: enabledLanguagesRaw)
        return SupportedLanguage.allCases.filter { enabled.contains($0) }
    }

    /// Every supported language, not just the ones currently shown on
    /// Samples import — connecting a dictionary is often exactly how a
    /// language not yet enabled gets turned on, so the picker shouldn't be
    /// limited to what's already enabled.
    private var allLanguagesSorted: [SupportedLanguage] {
        SupportedLanguage.allCases.sorted { $0.displayName < $1.displayName }
    }

    private var trimmedOtherName: String {
        otherLanguageName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The language the file will be tagged with, or nil while "Other
    /// language…" is chosen but no name has been typed yet.
    private var selectedLanguage: SupportedLanguage? {
        switch choice {
        case .listed(let language): return language
        case .other:
            guard !trimmedOtherName.isEmpty else { return nil }
            return SupportedLanguage.allCases.first { $0.displayName.caseInsensitiveCompare(trimmedOtherName) == .orderedSame }
        }
    }

    private let acceptedTypes: [UTType] = [.pdf, .plainText, .utf8PlainText, .commaSeparatedText, .tabSeparatedText, .text]

    struct ParsedEntry: Identifiable {
        let id = UUID()
        let term: String
        let definition: String
    }

    var body: some View {
        NavigationStack {
            connectForm
                .navigationTitle("Connect Local Dictionary")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Connect") { connect() }
                            .disabled(parsedEntries.isEmpty || isParsing || (choice == .other && trimmedOtherName.isEmpty))
                    }
                }
                .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: acceptedTypes) { result in
                    handleFileImport(result)
                }
                .alert("Couldn't import that file", isPresented: Binding(
                    get: { importError != nil },
                    set: { if !$0 { importError = nil } }
                )) {
                    Button("OK") { importError = nil }
                } message: {
                    Text(importError ?? "")
                }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var connectForm: some View {
        Form {
            Section {
                Picker("Language", selection: $choice) {
                    Text("Other language…").tag(LanguageChoice.other)
                    Divider()
                    ForEach(allLanguagesSorted, id: \.self) { language in
                        Text(language.displayName).tag(LanguageChoice.listed(language))
                    }
                }
                if choice == .other {
                    TextField("Language name (e.g. Navajo)", text: $otherLanguageName)
                        .autocorrectionDisabled()
                }
            } footer: {
                Text("Every term in the file is tagged with this language. Once connected, it becomes the default for new Samples and is shown in Settings' language list, where you can turn it on and off. A language that isn't listed is added there for you.")
            }

            Section {
                Button {
                    isFileImporterPresented = true
                } label: {
                    Label(fileName ?? "Select Dictionary File", systemImage: "doc.badge.plus")
                }
            } footer: {
                Text("A PDF or plain-text dictionary from Files, iCloud Drive, or On My iPhone/iPad — either a simple two-column word list, or a compiled dictionary with one entry per line.")
            }

            if isParsing {
                Section {
                    HStack {
                        ProgressView()
                        Text("Parsing…")
                    }
                }
            } else if fileName != nil {
                Section {
                    Text("\(parsedEntries.count) term\(parsedEntries.count == 1 ? "" : "s") found")
                    if duplicateCount > 0 {
                        Text("\(duplicateCount) already in your glossary as a manual entry, will be kept as-is")
                            .foregroundStyle(.secondary)
                    }
                }

                if !parsedEntries.isEmpty {
                    Section("Preview") {
                        ForEach(parsedEntries.prefix(5)) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.term).font(.body.weight(.semibold))
                                Text(entry.definition)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        if parsedEntries.count > 5 {
                            Text("+ \(parsedEntries.count - 5) more")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .onAppear {
            choice = .listed(AppSettings.preferredDefaultLanguage(enabledLanguages: enabledLanguages))
        }
        .onChange(of: choice) { _, _ in recomputeDuplicates() }
        .onChange(of: otherLanguageName) { _, _ in recomputeDuplicates() }
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription

        case .success(let url):
            // .fileImporter hands back a security-scoped URL — must
            // bracket access, and create the bookmark while access is
            // still active, same as TextImportView does for picked files.
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            let bookmarkData = try? url.bookmarkData()
            let isPDF = url.pathExtension.lowercased() == "pdf"
            let extractedText: String? = isPDF
                ? PDFDocument(url: url)?.string
                : try? String(contentsOf: url, encoding: .utf8)
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }

            guard let text = extractedText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                importError = isPDF
                    ? "Couldn't find any text in that PDF — it may be a scanned document with no text layer."
                    : "Couldn't read that file as text."
                fileName = nil
                parsedEntries = []
                return
            }

            fileName = url.lastPathComponent
            pendingBookmarkData = bookmarkData
            parsedEntries = []
            isParsing = true

            Task {
                let result = await Task.detached(priority: .userInitiated) {
                    Self.parse(text)
                }.value

                await MainActor.run {
                    parsedEntries = result.entries
                    isParsing = false
                    recomputeDuplicates()
                    if result.entries.isEmpty {
                        importError = "Couldn't find any term/definition pairs in that file."
                    }
                }
            }
        }
    }

    /// Only hand-typed terms count as duplicates — the same word in two
    /// different connected dictionaries is legitimate (each keeps its own
    /// definition), so other dictionaries' terms are never skipped.
    private func recomputeDuplicates() {
        guard let language = selectedLanguage else {
            duplicateCount = 0
            return
        }
        let manualKeys = Set(
            GlossaryStore.load()
                .filter { $0.source == .manual }
                .map { "\($0.language.rawValue)::\($0.term.lowercased())" }
        )
        duplicateCount = parsedEntries.filter { manualKeys.contains("\(language.rawValue)::\($0.term.lowercased())") }.count
    }

    // MARK: - Parsing

    /// Decides which layout the file is in by sampling its first non-empty
    /// lines, then parses accordingly.
    static func parse(_ text: String) -> (entries: [ParsedEntry], skippedCount: Int) {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        guard !lines.isEmpty else { return ([], 0) }

        let sample = lines.prefix(20)
        let tabularHits = sample.filter { splitColumns($0) != nil }.count
        if tabularHits >= max(1, sample.count / 2) {
            var entries: [ParsedEntry] = []
            var skipped = 0
            for line in lines {
                if let columns = splitColumns(line) {
                    entries.append(ParsedEntry(term: columns.0, definition: columns.1))
                } else {
                    skipped += 1
                }
            }
            return (entries, skipped)
        }

        return parseHeadwordEntries(text)
    }

    /// Parses a running-text dictionary where each entry starts with a
    /// headword at the beginning of a line — optionally followed by a
    /// parenthetical variant and/or a bracketed etymology — then a colon
    /// introducing the definition, which may wrap across several lines
    /// until the next headword.
    private static func parseHeadwordEntries(_ text: String) -> (entries: [ParsedEntry], skippedCount: Int) {
        let pattern = #"(?m)^([\p{L}][\p{L}'’\-]{0,39})(?:\s*\([^)\n]{0,80}\))?(?:\s*\[[^\]\n]{0,120}\])?\s*:\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return ([], 0) }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return ([], 0) }

        var entries: [ParsedEntry] = []
        var skipped = 0
        for (index, match) in matches.enumerated() {
            guard
                match.range(at: 1).location != NSNotFound,
                let termRange = Range(match.range(at: 1), in: text)
            else {
                skipped += 1
                continue
            }
            let term = String(text[termRange]).trimmingCharacters(in: .whitespaces)

            let definitionStart = match.range.location + match.range.length
            let definitionEnd = index + 1 < matches.count ? matches[index + 1].range.location : nsText.length
            guard
                definitionEnd > definitionStart,
                let definitionRange = Range(NSRange(location: definitionStart, length: definitionEnd - definitionStart), in: text)
            else {
                skipped += 1
                continue
            }

            let definition = String(text[definitionRange])
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)

            guard !term.isEmpty, !definition.isEmpty else {
                skipped += 1
                continue
            }
            entries.append(ParsedEntry(term: term, definition: definition))
        }
        return (entries, skipped)
    }

    private static func splitColumns(_ line: String) -> (String, String)? {
        if let pair = twoColumns(line, delimiter: "\t") { return pair }
        if let pair = csvColumns(line) { return pair }
        if let pair = twoColumns(line, delimiter: " - ") { return pair }
        if let pair = twoColumns(line, delimiter: " | ") { return pair }
        if let pair = twoColumns(line, delimiter: "|") { return pair }
        return nil
    }

    private static func twoColumns(_ line: String, delimiter: String) -> (String, String)? {
        let parts = line.components(separatedBy: delimiter)
        guard parts.count == 2 else { return nil }
        let term = parts[0].trimmingCharacters(in: .whitespaces)
        let definition = parts[1].trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty, !definition.isEmpty else { return nil }
        return (term, definition)
    }

    /// Minimal CSV split: honors double-quoted fields (so a definition
    /// containing a comma doesn't get split apart) but doesn't attempt
    /// escaped-quote (`""`) handling — good enough for the simple two-
    /// column exports this layout targets.
    private static func csvColumns(_ line: String) -> (String, String)? {
        guard line.contains(",") else { return nil }
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        guard fields.count == 2 else { return nil }
        let term = fields[0].trimmingCharacters(in: .whitespaces)
        let definition = fields[1].trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty, !definition.isEmpty else { return nil }
        return (term, definition)
    }

    // MARK: - Actions

    private func connect() {
        guard let bookmarkData = pendingBookmarkData, let connectedFileName = fileName else { return }

        let language: SupportedLanguage
        switch choice {
        case .listed(let listed): language = listed
        case .other: language = CustomLanguageStore.register(name: trimmedOtherName)
        }

        let dictionaryID = UUID()
        var existing = GlossaryStore.load()

        var seenKeys = Set(
            existing.filter { $0.source == .manual }.map { "\($0.language.rawValue)::\($0.term.lowercased())" }
        )
        var added = 0
        for parsed in parsedEntries {
            let key = "\(language.rawValue)::\(parsed.term.lowercased())"
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            existing.insert(
                GlossaryEntry(id: UUID(), term: parsed.term, definition: parsed.definition, language: language, addedAt: .now, source: .connectedDictionary, dictionaryID: dictionaryID),
                at: 0
            )
            added += 1
        }
        GlossaryStore.save(existing)

        ConnectedDictionaryStore.add(
            ConnectedDictionary(id: dictionaryID, fileName: connectedFileName, language: language, connectedAt: .now, termCount: added, bookmarkData: bookmarkData)
        )
        UserDefaults.standard.set(language.rawValue, forKey: AppSettings.defaultImportLanguageKey)

        // Show up as a Samples language immediately — connecting a
        // dictionary is often exactly how a language gets turned on for
        // the first time, and the terms are useless for cross-referencing
        // Samples if the language itself isn't selectable there.
        var enabled = AppSettings.languages(from: enabledLanguagesRaw)
        enabled.insert(language)
        enabledLanguagesRaw = AppSettings.rawValue(from: enabled)

        dismiss()
    }
}

#Preview {
    ConnectLocalDictionaryView()
}
