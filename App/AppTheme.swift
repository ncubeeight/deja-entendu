import SwiftUI

/// The palette from the "Déjà Entendu" home-screen design
/// (claude.ai/code/artifact/ee88d591-cb09-4093-a70a-4dbf66bf8534), lifted
/// into SwiftUI. Kept as plain Color constants rather than an asset
/// catalog color set so it's a single file to adjust.
enum AppTheme {
    static let background = Color(hex: 0xFBF6EF)
    static let surface = Color(hex: 0xFFFDF9)
    static let ink = Color(hex: 0x241C16)
    static let inkSoft = Color(hex: 0x7A6F63)
    static let line = Color(hex: 0xECE3D8)

    static let coral = Color(hex: 0xFF6B4A)
    static let coralSoft = Color(hex: 0xFFE4DA)
    static let teal = Color(hex: 0x2BBAA3)
    static let tealSoft = Color(hex: 0xDFF6F1)
    static let sky = Color(hex: 0x3D84D6)
    static let skySoft = Color(hex: 0xE1EDFB)
    static let gold = Color(hex: 0xE8A93D)
    static let goldSoft = Color(hex: 0xFCEFD7)
    static let lavender = Color(hex: 0x8B7CD6)
    static let lavenderSoft = Color(hex: 0xEAE6FA)
    static let rose = Color(hex: 0xE0609E)
    static let roseSoft = Color(hex: 0xFBE3EE)

    /// Soft backgrounds cycled across consecutive parsed words/tokens so
    /// word boundaries stay visible even in scripts with no whitespace
    /// between words (Japanese, Chinese) — the same six-hue set used
    /// elsewhere just at reduced saturation, so it reads as an accent
    /// rather than competing with the ink/coral UI.
    static let rainbow: [Color] = [coralSoft, goldSoft, tealSoft, skySoft, lavenderSoft, roseSoft]

    // Matches the blue-green header gradient on the GitHub Pages site
    // (jekyll-theme-cayman's .page-header: linear-gradient(120deg, #155799, #159957)).
    static let headerGradientStart = Color(hex: 0x155799)
    static let headerGradientEnd = Color(hex: 0x159957)
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
