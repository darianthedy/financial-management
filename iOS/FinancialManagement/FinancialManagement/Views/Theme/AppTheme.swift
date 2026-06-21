import SwiftUI

/// Centralized design-token layer for the iOS app.
///
/// These tokens mirror the web app's design system, which is the single source
/// of truth for visual design. The web tokens live in
/// `web/src/styles/globals.css` (the `@theme` block plus `.dark` overrides) and
/// are expressed there as HSL values with full light + dark variants. Each
/// color below resolves to a named color set in `Assets.xcassets` whose
/// "Any" (light) and "Dark" appearance values are the sRGB conversions of
/// those HSL values, so the colors track the system light/dark setting exactly
/// the way web's class-based dark mode does.
///
/// Screens should reference these tokens (`Color.appPrimary`, `Color.appCard`,
/// `AppTheme.cornerRadius`, …) instead of ad-hoc colors so the whole app stays
/// aligned with web in one place.
enum AppTheme {
    /// Matches web's `--radius: 0.625rem` (10pt at the web 16px root font size).
    static let cornerRadius: CGFloat = 10
}

extension Color {
    /// Brand / interactive accent. web `--color-primary`.
    static let appPrimary = Color("AppPrimary")
    /// Foreground on top of `appPrimary`. web `--color-primary-foreground`.
    static let appPrimaryForeground = Color("AppPrimaryForeground")

    /// Positive / income. web `--color-success`.
    static let appSuccess = Color("AppSuccess")
    /// Foreground on top of `appSuccess`. web `--color-success-foreground`.
    static let appSuccessForeground = Color("AppSuccessForeground")

    /// Negative / destructive. web `--color-danger`.
    static let appDanger = Color("AppDanger")
    /// Foreground on top of `appDanger`. web `--color-danger-foreground`.
    static let appDangerForeground = Color("AppDangerForeground")

    /// Caution. web `--color-warning`.
    static let appWarning = Color("AppWarning")
    /// Foreground on top of `appWarning`. web `--color-warning-foreground`.
    static let appWarningForeground = Color("AppWarningForeground")

    /// Subtle surface (chips, fills). web `--color-muted`.
    static let appMuted = Color("AppMuted")
    /// Secondary / de-emphasized text. web `--color-muted-foreground`.
    static let appMutedForeground = Color("AppMutedForeground")

    /// Card surface. web `--color-card`.
    static let appCard = Color("AppCard")
    /// Text on top of a card. web `--color-card-foreground`.
    static let appCardForeground = Color("AppCardForeground")

    /// App backdrop. web `--color-background`.
    static let appBackground = Color("AppBackground")
    /// Primary text on the backdrop. web `--color-foreground`.
    static let appForeground = Color("AppForeground")

    /// Hairline / divider. web `--color-border`.
    static let appBorder = Color("AppBorder")
    /// Form-control border. web `--color-input`.
    static let appInput = Color("AppInput")
    /// Focus ring. web `--color-ring`.
    static let appRing = Color("AppRing")
}
