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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Select a word to see the translation from your device's built-in language model")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                ForEach(Array(lines.enumerated()), id: \.offset) { row, words in
                    HStack(spacing: 0) {
                        ForEach(Array(words.enumerated()), id: \.offset) { col, word in
                            WordToken(
                                word: word,
                                line: words.joined(),
                                color: Self.color(forRow: row, col: col, in: words)
                            )
                        }
                    }
                }

                Link("Japanese Iroha poem", destination: URL(string: "https://en.wikipedia.org/wiki/Iroha")!)
                    .font(.footnote)
                    .padding(.top, 12)
            }
            .padding(.vertical, 32)
        }
        .navigationTitle("Example interaction")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static func color(forRow row: Int, col: Int, in words: [String]) -> Color {
        let globalIndex = row * 2 + col  // every line here has exactly 2 words
        return palette[globalIndex % palette.count]
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
            .font(.system(size: 30))
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
