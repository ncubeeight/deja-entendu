import SwiftUI

/// The three kinds of source material the Samples tab can hold. Centralizes
/// the icon/color pairing so audio, text, and image rows stay visually
/// consistent everywhere they're shown (Samples tab, Home's "Continue
/// studying", the add-sample action sheet).
enum SampleKind: String, CaseIterable, Equatable {
    case audio
    case text
    case image

    var label: String {
        switch self {
        case .audio: "Audio"
        case .text: "Text"
        case .image: "Image"
        }
    }

    var icon: String {
        switch self {
        case .audio: "waveform"
        case .text: "doc.text"
        case .image: "photo"
        }
    }

    var tint: Color {
        switch self {
        case .audio: AppTheme.coral
        case .text: AppTheme.sky
        case .image: AppTheme.teal
        }
    }

    var tintSoft: Color {
        switch self {
        case .audio: AppTheme.coralSoft
        case .text: AppTheme.skySoft
        case .image: AppTheme.tealSoft
        }
    }
}
