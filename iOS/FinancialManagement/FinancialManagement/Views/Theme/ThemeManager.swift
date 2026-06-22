import SwiftUI
import Observation

/// The user's theme preference. Mirrors web's `useTheme` hook
/// (`web/src/lib/hooks/use-theme.tsx`) and its `Theme` union: an explicit
/// Light/Dark choice or "System", which follows the device appearance setting.
enum AppThemePreference: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    /// Title-cased label shown in the Settings toggle, matching web's
    /// `THEME_OPTIONS` ("Light" / "Dark" / "System").
    var label: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }

    /// The color scheme to force, or `nil` to defer to the system setting.
    /// Applied at the app root via `.preferredColorScheme`, the SwiftUI analog
    /// of web toggling `<html class="dark">`.
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

/// Shares the user's theme preference across the app and persists it across
/// launches. Mirrors web's `ThemeProvider`, which stores the choice in
/// `localStorage` under the `"theme"` key and defaults to `"system"` when unset.
@Observable
@MainActor
final class ThemeManager {
    /// Same storage key web uses, so the intent reads identically across apps.
    private static let storageKey = "theme"

    var preference: AppThemePreference {
        didSet {
            UserDefaults.standard.set(preference.rawValue, forKey: Self.storageKey)
        }
    }

    /// The color scheme to apply right now (`nil` while on "System").
    var colorScheme: ColorScheme? { preference.colorScheme }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        preference = stored.flatMap(AppThemePreference.init(rawValue:)) ?? .system
    }
}
