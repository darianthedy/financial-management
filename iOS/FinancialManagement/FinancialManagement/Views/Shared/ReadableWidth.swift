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
}

extension View {
    /// Applies `ReadableWidth` to a scrolling list. No-op on compact width.
    func readableContentMargins() -> some View {
        modifier(ReadableContentMargins())
    }
}

private struct ReadableContentMargins: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentMargins(
                .horizontal,
                ReadableWidth.margin(width: width, sizeClass: horizontalSizeClass),
                for: .scrollContent
            )
            // Content margins are measured from the list's edges, not from its
            // safe area, so include a vertical bar's inset in the width.
            .onGeometryChange(for: CGFloat.self) {
                $0.size.width + $0.safeAreaInsets.leading + $0.safeAreaInsets.trailing
            } action: { width = $0 }
    }
}
