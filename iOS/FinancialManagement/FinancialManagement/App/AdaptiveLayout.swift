import SwiftUI

/// The iPhone Duo **adaptive kill switch** (docs/ios-iphone-duo-implementation-plan.md §1.4).
///
/// Regular-width layouts land on `main` in small PRs, but must not reach
/// TestFlight or iPad users until they are finished. The switch is the
/// `ADAPTIVE_LAYOUT_ENABLED` build setting, surfaced through Info.plist:
/// **on** for Debug, **off** for Release (TestFlight / App Store) until D7.1.
///
/// While off, `AdaptiveLayoutGate` pins the horizontal size class to
/// `.compact` at the root, so every device renders today's compact layout.
enum AdaptiveLayout {
    static let infoKey = "ADAPTIVE_LAYOUT_ENABLED"

    /// Whether regular-width (adaptive) layouts are allowed in this build.
    static let isEnabled = isEnabled(infoValue: Bundle.main.object(forInfoDictionaryKey: infoKey))

    /// Parses the Info.plist value. Missing or unrecognised values mean **off**,
    /// so a misconfigured build fails safe to the compact layout.
    static func isEnabled(infoValue: Any?) -> Bool {
        switch infoValue {
        case let flag as Bool:
            return flag
        case let text as String:
            return ["yes", "true", "1"].contains(text.trimmingCharacters(in: .whitespaces).lowercased())
        case let number as NSNumber:
            return number.boolValue
        default:
            return false
        }
    }

    /// The size class views should see: the system's when enabled, else compact.
    static func effectiveSizeClass(
        _ system: UserInterfaceSizeClass?, enabled: Bool = isEnabled
    ) -> UserInterfaceSizeClass? {
        enabled ? system : .compact
    }
}

/// Applied once at the app root. See `AdaptiveLayout`.
struct AdaptiveLayoutGate: ViewModifier {
    var enabled: Bool = AdaptiveLayout.isEnabled
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content.environment(
            \.horizontalSizeClass,
            AdaptiveLayout.effectiveSizeClass(horizontalSizeClass, enabled: enabled)
        )
    }
}

extension View {
    /// Pins the horizontal size class to compact unless the adaptive kill
    /// switch is on. Apply once, at the root.
    func adaptiveLayoutGate(enabled: Bool = AdaptiveLayout.isEnabled) -> some View {
        modifier(AdaptiveLayoutGate(enabled: enabled))
    }
}
