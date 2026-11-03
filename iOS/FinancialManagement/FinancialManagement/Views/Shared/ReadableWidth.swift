import SwiftUI

/// Keeps a full-width grouped `List` readable on the inner display (design
/// §S13, implementation plan D5.2), so Settings' segmented Theme picker doesn't
/// stretch across 951 pt. Derived from the width, not a breakpoint. Pure, so
/// it's unit-tested directly.
enum ReadableWidth {
    /// The widest a section may be. Also caps the rows inside it.
    static let maximumContentWidth: CGFloat = 560

    /// The horizontal content margin, or nil to keep the system's: always on
    /// compact, and whenever the width already fits.
    static func margin(width: CGFloat, sizeClass: UserInterfaceSizeClass?) -> CGFloat? {
        guard sizeClass == .regular, width > maximumContentWidth else { return nil }
        return ((width - maximumContentWidth) / 2).rounded(.up)
    }

    /// The leading and trailing content margins for a list `width` wide inside
    /// its safe area, with `insets` outside it on each side, or nil to keep the
    /// system's. Content margins are measured from the list's edges and replace
    /// the safe area, so each side adds its own inset back: the content stays
    /// clear of a floating sidebar on one side and a vertical bar on the other.
    static func margins(
        width: CGFloat, leadingInset: CGFloat, trailingInset: CGFloat,
        sizeClass: UserInterfaceSizeClass?
    ) -> (leading: CGFloat, trailing: CGFloat)? {
        guard let margin = margin(width: width, sizeClass: sizeClass) else { return nil }
        return (leadingInset + margin, trailingInset + margin)
    }
}

extension View {
    /// Applies `ReadableWidth` to a scrolling list. No-op on compact width.
    func readableContentMargins() -> some View {
        modifier(ReadableContentMargins())
    }
}

private struct ReadableContentMargins: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var geometry = Geometry()

    nonisolated private struct Geometry: Equatable, Sendable {
        var width: CGFloat = 0
        var leading: CGFloat = 0
        var trailing: CGFloat = 0
    }

    func body(content: Content) -> some View {
        let margins = ReadableWidth.margins(
            width: geometry.width, leadingInset: geometry.leading,
            trailingInset: geometry.trailing, sizeClass: horizontalSizeClass
        )
        content
            .contentMargins(.leading, margins?.leading, for: .scrollContent)
            .contentMargins(.trailing, margins?.trailing, for: .scrollContent)
            // The width inside the safe area, and the insets beside it: a
            // floating sidebar on the leading side (it fills the whole leading
            // region in book posture), a vertical bar on the trailing side.
            .onGeometryChange(for: Geometry.self) {
                Geometry(
                    width: $0.size.width,
                    leading: $0.safeAreaInsets.leading,
                    trailing: $0.safeAreaInsets.trailing
                )
            } action: { geometry = $0 }
    }
}
