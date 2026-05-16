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
            return [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]
        case .sunset:
            return [Color(hex: "2b1055"), Color(hex: "7597de")] // Night to day transition style or deep purple
        case .forest:
            return [Color(hex: "134E5E"), Color(hex: "71B280")]
        case .monochrome:
            return [Color(hex: "000000"), Color(hex: "434343")]
        }
    }
    
    // Accent Color
    var accentColor: Color {
        switch self {
        case .darkMarine: return Color(hex: "00d2ff")
        case .sunset: return Color(hex: "FF512F") // Orange/Red
        case .forest: return Color(hex: "A8E063") // Light Green
        case .monochrome: return Color(hex: "FFFFFF")
        }
    }
    
    // Secondary Accent
    var secondaryAccentColor: Color {
        switch self {
        case .darkMarine: return Color(hex: "3a7bd5")
        case .sunset: return Color(hex: "F09819")
        case .forest: return Color(hex: "56ab2f")
        case .monochrome: return Color(hex: "bdc3c7")
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
    // Current Preset Access Helper
    // Note: In Views, prefer using @ObservedObject or @AppStorage to react to changes.
    // Static properties here read from the source of truth (UserDefaults via AppStorage wrapper logic or direct access)
    // To enable reactivity without passing ThemeManager everywhere, we can make these computed properties 
    // but Views won't update automatically unless they observe the manager.
    // For simplicity in this codebase, we'll keep static access for properties, 
    // AND integrate ThemeManager in root view or EnvironmentObject.
    
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
        return .white.opacity(0.7)
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
        return .system(size: 18, weight: .semibold, design: .rounded)
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
