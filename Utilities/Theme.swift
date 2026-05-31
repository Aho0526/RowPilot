import SwiftUI

// MARK: - Theme Presets
enum ThemePreset: String, CaseIterable, Identifiable {
    case darkMarine = "Dark Marine"
    case sunset = "Sunset"
    case forest = "Forest"
    case monochrome = "Monochrome"
    
    var id: String { self.rawValue }
    
    // Background Gradient Colors
    var backgroundColors: [Color] {
        switch self {
        case .darkMarine:
            return [Color(hex: "040B14"), Color(hex: "0A172A"), Color(hex: "081120")]
        case .sunset:
            return [Color(hex: "0E0814"), Color(hex: "1C0E2D"), Color(hex: "180B22")]
        case .forest:
            return [Color(hex: "040D08"), Color(hex: "0B2215"), Color(hex: "07180F")]
        case .monochrome:
            return [Color(hex: "080808"), Color(hex: "171717"), Color(hex: "101010")]
        }
    }
    
    // Accent Color
    var accentColor: Color {
        switch self {
        case .darkMarine: return Color(hex: "00F2FE") // Electric Cyan
        case .sunset: return Color(hex: "FF0844") // Neon Pink
        case .forest: return Color(hex: "00FF87") // Laser Green
        case .monochrome: return Color(hex: "D4AF37") // Premium Gold
        }
    }
    
    // Secondary Accent
    var secondaryAccentColor: Color {
        switch self {
        case .darkMarine: return Color(hex: "4FACFE") // Neon Blue
        case .sunset: return Color(hex: "FFB199") // Electric Peach
        case .forest: return Color(hex: "60EFFF") // Electric Teal
        case .monochrome: return Color(hex: "E0E0E0") // Platinum
        }
    }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @AppStorage("selectedThemePreset") var currentPreset: ThemePreset = .darkMarine
    
    func setTheme(_ preset: ThemePreset) {
        currentPreset = preset
    }
}

// MARK: - Theme Accessor
struct Theme {
    static var current: ThemePreset {
        ThemeManager.shared.currentPreset
    }
    
    static var background: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: current.backgroundColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var mainBackground: Color {
        current.backgroundColors.first ?? .black
    }
    
    static var cardBackground: Material {
        return .ultraThin
    }
    
    static var accent: Color {
        current.accentColor
    }
    
    static var secondaryAccent: Color {
        current.secondaryAccentColor
    }
    
    static var textMain: Color {
        return .white
    }
    
    static var textSecondary: Color {
        return .white.opacity(0.65)
    }
    
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [accent, secondaryAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Font Styles
    static func headerFont() -> Font {
        return .system(size: 24, weight: .bold, design: .rounded)
    }
    
    static func subHeaderFont() -> Font {
        return .system(size: 17, weight: .semibold, design: .rounded)
    }
}

// MARK: - View Extension for futuristic UI modifiers
extension View {
    func glassCardStyle(glowColor: Color = .white, opacity: Double = 0.1, cornerRadius: CGFloat = 16) -> some View {
        self
            .background(Theme.cardBackground)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.18), .clear, glowColor.opacity(opacity * 2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: glowColor.opacity(opacity), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 1, 1, 1)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

