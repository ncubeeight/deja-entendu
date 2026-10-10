import SwiftUI

/// A tap-to-define reading practice screen: the Iroha, a classical Japanese
/// pangram poem, laid out word-by-word with each word colored distinctly so
/// word boundaries are visually obvious in unspaced hiragana. Tapping a word
/// looks up a short English gloss via the on-device model (WordGlossGenerator).
struct IrohaExplorerView: View {

    private let lines: [[String]] = [
        ["いろは", "にほへと"],
        ["ちりぬる", "を"],
        ["わかよ", "たれそ"],
        ["つね", "ならむ"],
        ["うゐの", "おくやま"],
        ["けふ", "こえて"],
        ["あさき", "ゆめみし"],
        ["ゑひも", "せす"],
    ]

    private static let palette: [Color] = [
        Color(red: 0.84, green: 0.16, blue: 0.16),  // red
        Color(red: 0.91, green: 0.43, blue: 0.06),  // orange
        Color(red: 0.77, green: 0.54, blue: 0.02),  // amber
        Color(red: 0.09, green: 0.52, blue: 0.24),  // green
        Color(red: 0.03, green: 0.57, blue: 0.59),  // teal
        Color(red: 0.15, green: 0.33, blue: 0.82),  // blue
        Color(red: 0.43, green: 0.16, blue: 0.75),  // violet
        Color(red: 0.75, green: 0.09, blue: 0.46),  // magenta
    ]

    /// Flattened so the poem can wrap to fill each line naturally (FlowLayout)
    /// instead of being locked to a fixed 2-words-per-row grid — the couplet
    /// breaks were a layout artifact, not a meaningful word boundary, so
    /// flattening loses nothing while freeing up vertical space below.
    private var allWords: [(word: String, line: String, color: Color)] {
        var result: [(word: String, line: String, color: Color)] = []
        var globalIndex = 0
        for words in lines {
            let line = words.joined()
            for word in words {
                result.append((word, line, Self.palette[globalIndex % Self.palette.count]))
                globalIndex += 1
            }
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Select a word to see the translation from your device's built-in language model")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                FlowLayout(spacing: 6) {
                    ForEach(Array(allWords.enumerated()), id: \.offset) { _, item in
                        WordToken(word: item.word, line: item.line, color: item.color)
                    }
                }
                .padding(.horizontal, 24)

                Link("Japanese Iroha poem", destination: URL(string: "https://en.wikipedia.org/wiki/Iroha")!)
                    .font(.footnote)
                    .padding(.top, 12)

                usageGuidelines
            }
            .padding(.vertical, 32)
        }
        .navigationTitle("Example interaction")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var usageGuidelines: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Usage Guidelines:")
                .font(.title2.bold())

            Text("Déjà Entendu (\"Already heard\" in French) allows iOS, iPadOS and macOS versions of the app to translate, transcribe and create flash cards from images, recordings or sound samples on the device. You can be assured that any use of the on-device content analysis that Apple Intelligence performs stays private to you. No information on the usage of translation services is sent to Apple nor the developer.")

            Text("Use Déjà Entendu to import your class pdf notes or to translate and transcribe audio clips that you've made or that you've purchased and imported to your iPhone or Mac previously. We support over 40 languages across the world for recognizing and translating text. All of the languages that Apple Intelligence can read aloud will be spoken on your device in the local language from the Samples and Vocabulary tabs. (Note that iPhone 15 Pro and later models with iOS 26 or later support these large language model capabilities. iPhones prior to that will need to download supplemental dictionaries in the Settings tab, as flashcard generation relies on an Apple powered utility on newer devices or Macs. Also, the Apple Intelligence tools need to be turned on for the device for them to work in Déjà Entendu.)")

            Text("To select a new language of study, add the language in the Settings tab and turn off any languages you don't currently need to study. This will create more space for languages you prefer in the Samples tab. Then when you upload a sample, ask the app to transcribe it in the language of the sample. (Parsing Japanese as Chinese for instance would result in a different pronunciation of the characters or similarly a mispronunciation between Latin-based languages as spellings and phonetics of alphabet-based languages vary among countries and linguistic groups.) We have utilized user-instructed language selection rather than web-based language detection to ensure that all app activity stays local on device without calls to the web for cloud-based translation tools. The parsed transcription in the Samples menu will then give you a breakdown of the word separation in the language sample you’ve provided, color coded for each term in the sample. Each term, when selected, will give you a definition, a pronunciation and the option to create a flashcard. From this step, add them to your Vocabulary list for later practice. If you don't already have a picture or text sample, select “Generate Sample”. (This feature supports iPhones, iPads and Macs that have Apple Intelligence enabled. Note that Apple does not offer the Apple Intelligence feature on iPhones earlier than iPhone 15 Pro, and it requires iOS 26 or later.)")

            Text("Déjà Entendu has a “Record Live” option in the Samples tab to create an example sentence for practice either from a tutor or by you speaking the words directly into the app. This is not a Voice Memo utility. Audio put into this utility will not result in a permanent recording on your iPhone or Mac. It is used for generating the transcription only. The samples are not exportable files, the microphone is only used in the step of making the transcription of the ambient audio, not any background sound. It is also important to note that Voice Memo files on your iPhone are not accessible to Déjà Entendu, by Apple design. Apple protects content on some apps from being available to other apps when such access would result in vulnerability to personal privacy. This is a good thing from a data privacy perspective. But it means that language learners would need to import audio samples into the Files folder on their device if they plan to import notes or recordings from language study materials. Déjà Entendu and our developer team do not have a repository of language study catalogs for license. You may import files from other study lists and notes you’ve created if you have copyright or license to them. In similar fashion, you can export your Vocabulary lists from Déjà Entendu to other study apps that you use from the Share icon at the top of the Vocabulary tab. We do not have any formal or planned services for integrated third party content. Our app is intended as a complement to other existing study materials or real-life witnessed text as you travel.")

            Text("The Custom Glossary utility in the Settings tab is meant for app users to add terms into their Vocabulary lists that are not part of the Apple dictionaries nor part of the language model of Apple Intelligence’s foundation model distributed with your iPhone. This is a user generated text-entry field for your convenience. Sometimes regions of the world have idiomatic vocabulary that is not common in standard dictionaries but that you would like to integrate into your flashcards. If there are terms you want to study that aren't taken from a sample, these can be included in a Custom Glossary that is unique to you, even if the on-device language model is unfamiliar with the term.")

            Text("Over time your home screen in the app will feature the samples and vocabulary previously registered with the app so that you can return to study projects you left off.")

            Text("It is important to note that because this is a private use app with no associated cloud services, the Vocabulary lists and Samples are personal to your device and are not synced on an account system, nor shared between any two apps that you install on your devices with your Apple ID. This means that your data is local to device and not backed up. So if you use an iPhone, iPad and Mac version of the app (all are included in one purchase) the flashcards you create will not synchronize between them. Privacy by design is important to us and to Apple. So if you wish to export your Vocabulary to another device or service, please do that from the Vocabulary tab and then re-import to your other apps or devices.")

            Text("Please feel free to follow our app use stories and inspirations on our social channels. Please do not include any personally identifiable information in our social channels. They are meant for sharing news and updates rather than personal conversations.")

            VStack(alignment: .leading, spacing: 6) {
                Link("Facebook", destination: URL(string: "https://www.facebook.com/p/D%C3%A9j%C3%A0-Entendu-61594895031068/")!)
                Link("Bluesky", destination: URL(string: "https://bsky.app/profile/dejaentendustudy.bsky.social")!)
                Link("Instagram", destination: URL(string: "https://www.instagram.com/dejaentendustudy/")!)
            }

            Text("To share screenshots, feature requests or to report an app error, please share details here in this non-public feedback form:")
            Link("Feedback form", destination: URL(string: "https://forms.gle/BVUZQFHmUwzf6KjVA")!)

            Text("We hope you enjoy learning more of the languages that inspire you through our apps!")
        }
        .font(.body)
        .padding(.horizontal, 24)
    }
}

private struct WordToken: View {
    let word: String
    let line: String
    let color: Color

    @State private var isSelected = false
    @State private var glossState: GlossState = .idle

    private enum GlossState: Equatable {
        case idle
        case loading
        case ready(String)
        case failed(String)
    }

    var body: some View {
        Text(word)
            .font(.system(size: 20))
            .foregroundStyle(color)
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
            .background(
                isSelected ? Color.accentColor.opacity(0.22) : .clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                isSelected = true
                if glossState == .idle {
                    Task { await lookUp() }
                }
            }
            .popover(isPresented: $isSelected, arrowEdge: .top) {
                popoverContent
                    .presentationCompactAdaptation(.popover)
            }
    }

    @ViewBuilder
    private var popoverContent: some View {
        VStack(spacing: 6) {
            switch glossState {
            case .idle, .loading:
                ProgressView()
                Text("Looking up…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

            case .ready(let gloss):
                Label(gloss, systemImage: "sparkles")
                    .font(.headline)
                Text("On-device definition")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

            case .failed(let reason):
                Text(reason)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 200)
    }

    private func lookUp() async {
        glossState = .loading
        do {
            let gloss = try await WordGlossGenerator.gloss(forWord: word, inLine: line)
            glossState = .ready(gloss)
        } catch {
            glossState = .failed(error.localizedDescription)
        }
    }
}

#Preview {
    NavigationStack {
        IrohaExplorerView()
    }
}
