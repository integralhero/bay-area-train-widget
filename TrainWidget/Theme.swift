import SwiftUI

enum AppTheme {
    // MARK: - Colors (from asset catalog, auto light/dark)
    static let background = Color("background")
    static let surface = Color("surface")
    static let textPrimary = Color("textPrimary")
    static let muted = Color("muted")
    static let primary = Color("accentPrimary")
    static let secondary = Color("accentSecondary")
    static let border = Color("border")

    // Semantic
    static let success = Color("accentPrimary")
    static let error = Color("accentSecondary")
    static let warning = Color(red: 0.722, green: 0.525, blue: 0.043) // #B8860B

    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 18
    static let spacingXXL: CGFloat = 24

    // MARK: - Radii
    static let radiusChip: CGFloat = 4
    static let radiusButton: CGFloat = 6
    static let radiusInput: CGFloat = 6
    static let radiusCard: CGFloat = 8

    // MARK: - Hero
    static let heroHeight: CGFloat = 220
}
