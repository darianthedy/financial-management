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

    // MARK: - Spacing tokens (budget-related views)

    /// Horizontal inset for budget list rows and section headers. Shared by
    /// `BudgetListView`, `ActiveInstallmentsSection`, and the section header
    /// padding so all content aligns on the same column.
    static let cardHorizontalPadding: CGFloat = 16

    /// Top/bottom inset for each budget list row (the gap between cards).
    static let cardVerticalPadding: CGFloat = 6

    /// Vertical breathing room above and below section headings.
    static let sectionSpacing: CGFloat = 8

    /// Uniform inner padding applied inside every card surface (`BudgetCard`,
    /// `ActiveInstallmentsSection` rows). Changing this one token reflows all
    /// card content simultaneously.
    static let cardInnerPadding: CGFloat = 16
}

extension View {
    /// Mirrors web's `Card` surface (`web/src/components/ui/card.tsx`): the card
    /// fill, a 1pt hairline border, `--radius` corners and a subtle drop shadow
    /// (`shadow-sm`). Use on dashboard widgets so they read as bordered cards on
    /// the app background instead of translucent material.
    func appCardSurface() -> some View {
        self
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    /// Applies the standard `listRowInsets` for budget cards and installment
    /// rows so that all rows in `BudgetListView` align on the same horizontal
    /// column. Updating `AppTheme.cardHorizontalPadding` / `cardVerticalPadding`
    /// reflows every row at once.
    func budgetRowInsets() -> some View {
        listRowInsets(EdgeInsets(
            top: AppTheme.cardVerticalPadding,
            leading: AppTheme.cardHorizontalPadding,
            bottom: AppTheme.cardVerticalPadding,
            trailing: AppTheme.cardHorizontalPadding
        ))
    }
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

    /// Parses a web-style hex string (`#RGB`, `#RRGGBB`, or `#RRGGBBAA`) into a
    /// Color. Used for user-defined category colors, which web stores as hex and
    /// renders as a tinted chip (`{color}1a` fill, `color` text). Returns nil for
    /// malformed input so callers can fall back to the neutral chip styling.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard let value = UInt64(s, radix: 16) else { return nil }
        let r, g, b, a: Double
        switch s.count {
        case 3: // RGB
            r = Double((value >> 8) & 0xF) / 15
            g = Double((value >> 4) & 0xF) / 15
            b = Double(value & 0xF) / 15
            a = 1
        case 6: // RRGGBB
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        case 8: // RRGGBBAA
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default:
            return nil
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
