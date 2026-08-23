import SwiftUI

/// The "Home" tab: a quick-glance summary styled after the home-screen
/// design, but showing only what the app actually has data for.
///
/// Two things from the design are deliberately NOT here, rather than
/// faked: the streak / daily-goal ring (no streak tracking exists
/// anywhere in the app), and flip-to-reveal pinyin on vocabulary chips
/// (VocabularyEntry is freeform shared text — there's no separate
/// word/pinyin/translation to flip between). Both are natural follow-ups
/// once that data exists.
struct HomeSummaryView: View {
    @Binding var selectedTab: Int

    @State private var vocabulary: [VocabularyEntry] = VocabularyStore.load()
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
                VStack(alignment: .leading, spacing: 28) {
                    Text("You heard it before. Let's try to remember it.")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(AppTheme.inkSoft)

                    continueListeningSection
                    wordsToReviewSection
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationTitle("Déjà Entendu")
            .task { vocabulary = VocabularyStore.load() }
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

    @ViewBuilder
    private var continueListeningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue listening")
                .font(.headline)
                .fontDesign(.rounded)
                .foregroundStyle(AppTheme.ink)

            // Recordings live only in VoiceMemoImportView's in-memory
            // @State right now — nothing persists them, so Home has no
            // independent source to read from yet. Showing the honest
            // empty state rather than a fake list; wiring this up for
            // real means giving ImportedRecording a persisted store the
            // way VocabularyStore already does for vocabulary.
            Text("Recordings you import will show up here once they're saved between launches.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.inkSoft)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.line))
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
