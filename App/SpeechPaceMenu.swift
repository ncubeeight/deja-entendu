import SwiftUI

/// The tortoise / gauge / hare icon shown beside speak buttons. It hints at
/// the current speech speed and, when tapped, lets the user change it in
/// place — writing the same global setting as the Speech section in
/// Settings, so the choice carries across every screen.
struct SpeechPaceMenu: View {
    var font: Font = .title2

    @AppStorage(AppSettings.speechPaceKey) private var paceRaw: String = SpeechPace.normal.rawValue

    private var pace: SpeechPace {
        SpeechPace(rawValue: paceRaw) ?? .normal
    }

    var body: some View {
        Menu {
            Picker("Speech Speed", selection: $paceRaw) {
                ForEach(SpeechPace.allCases, id: \.self) { pace in
                    Label(pace.displayName, systemImage: pace.systemImage).tag(pace.rawValue)
                }
            }
        } label: {
            Image(systemName: pace.systemImage)
                .font(font)
        }
        .accessibilityLabel("Speech speed: \(pace.displayName)")
    }
}
