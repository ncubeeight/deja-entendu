import SwiftUI

/// The "Home" tab: a quick-glance summary styled after the home-screen
/// design, but showing only what the app actually has data for.
///
/// One thing from the design is deliberately NOT here, rather than faked:
/// the streak / daily-goal ring (no streak tracking exists anywhere in the
/// app) — a natural follow-up once that data exists. Vocabulary chips do
/// link to a real flashcard now (VocabularyFlashcardView).
struct HomeSummaryView: View {
    @Binding var selectedTab: Int

    @State private var vocabulary: [VocabularyEntry] = VocabularyStore.load()
    @State private var recordings: [ImportedRecording] = ImportedRecordingStore.load()
    @State private var isAddActionSheetPresented = false
    @State private var isAddWordSheetPresented = false

    /// One sample word per supported language, shown only until the user
    /// has real vocabulary — a preview of what the feature does, not fake
    /// data pretending to be real.
    private struct PlaceholderWord {
        let language: SupportedLanguage
        let word: String
        let gloss: String
    }

    private static let placeholderWords: [PlaceholderWord] = [
        PlaceholderWord(language: .chineseTraditional, word: "謝謝", gloss: "thank you"),
        PlaceholderWord(language: .chineseSimplified, word: "你好", gloss: "hello"),
        PlaceholderWord(language: .japanese, word: "こんにちは", gloss: "hello"),
        PlaceholderWord(language: .german, word: "Danke", gloss: "thank you"),
        PlaceholderWord(language: .french, word: "Bonjour", gloss: "hello"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    titleBanner

                    VStack(alignment: .leading, spacing: 28) {
                        continueListeningSection
                        wordsToReviewSection
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)
            }
            .background(AppTheme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ImportedRecording.self) { recording in
                TranscriptionRunnerView(recording: recording)
            }
            .navigationDestination(for: VocabularyEntry.self) { entry in
                VocabularyFlashcardView(entry: entry)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        IrohaExplorerView()
                    } label: {
                        Label("Example interaction", systemImage: "character.book.closed")
                    }
                }
            }
            .task {
                vocabulary = VocabularyStore.load()
                recordings = ImportedRecordingStore.load()
            }
            .confirmationDialog("Add to Déjà Entendu", isPresented: $isAddActionSheetPresented, titleVisibility: .visible) {
                Button("Import a Recording") { selectedTab = 1 }
                Button("Add a Word") { isAddWordSheetPresented = true }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $isAddWordSheetPresented, onDismiss: {
                vocabulary = VocabularyStore.load()
            }) {
                AddVocabularyWordView()
            }
        }
    }

    private func deleteRecording(_ recording: ImportedRecording) {
        withAnimation {
            recordings.removeAll { $0.id == recording.id }
        }
        ImportedRecordingStore.save(recordings)
        try? FileManager.default.removeItem(at: recording.localURL)
    }

    private func deleteVocabulary(_ entry: VocabularyEntry) {
        withAnimation {
            vocabulary.removeAll { $0.id == entry.id }
        }
        VocabularyStore.save(vocabulary)
    }

    @ViewBuilder
    private var titleBanner: some View {
        VStack(spacing: 10) {
            Text("Déjà Entendu")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("You heard it before.\nLet's try to remember it.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(
            LinearGradient(
                colors: [AppTheme.headerGradientStart, AppTheme.headerGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    @ViewBuilder
    private var continueListeningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue studying")
                .font(.headline)
                .fontDesign(.rounded)
                .foregroundStyle(AppTheme.ink)

            if recordings.isEmpty {
                Text("Recordings you import will show up here once they're saved between launches.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.inkSoft)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.line))
            } else {
                VStack(spacing: 10) {
                    ForEach(recordings.prefix(3)) { recording in
                        HStack(spacing: 8) {
                            NavigationLink(value: recording) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(recording.originalFilename)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.ink)
                                            .lineLimit(1)
                                        Text("\(recording.language.displayName) · \(recording.importedAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.inkSoft)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.inkSoft)
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                deleteRecording(recording)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.inkSoft)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(16)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.line))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var wordsToReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Words to review")
                .font(.headline)
                .fontDesign(.rounded)
                .foregroundStyle(AppTheme.ink)

            if vocabulary.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                    ForEach(Self.placeholderWords, id: \.word) { item in
                        placeholderCard(item)
                    }
                    addWordCard
                }
                Text("These are just examples — share a word from Translate, or add your own, to replace them.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkSoft)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                    ForEach(vocabulary.prefix(9)) { entry in
                        NavigationLink(value: entry) {
                            Text(entry.text)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 8)
                                .frame(maxWidth: .infinity)
                                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.line))
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .topTrailing) {
                            Button {
                                deleteVocabulary(entry)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.callout)
                                    .foregroundStyle(AppTheme.inkSoft)
                                    .background(AppTheme.surface, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .offset(x: 6, y: -6)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func placeholderCard(_ item: PlaceholderWord) -> some View {
        VStack(spacing: 4) {
            Text(item.word)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("\(item.gloss) · \(item.language.displayName)")
                .font(.caption2)
                .foregroundStyle(AppTheme.inkSoft)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.line))
    }

    @ViewBuilder
    private var addWordCard: some View {
        Button {
            isAddActionSheetPresented = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.coral)
                Text("Add your own")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.inkSoft)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(AppTheme.coralSoft, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.coral.opacity(0.4)))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeSummaryView(selectedTab: .constant(0))
}
