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
