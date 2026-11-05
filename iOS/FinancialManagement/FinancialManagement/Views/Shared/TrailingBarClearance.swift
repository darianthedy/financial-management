import SwiftUI

extension View {
    /// Keeps a plain `List` out from under the trailing safe area (the Duo
    /// outer display's vertical bar). SwiftUI stretches a scroll view that
    /// touches a safe-area edge to the screen edge, so the plain list's cells
    /// ran 84 pt under the bar and a swiped row slid by Delete *plus* the bar.
    /// Inset-grouped lists inset their cells and never had the problem.
    ///
    /// The Duo probe (`DuoProbeTests.test7_swipeList`) measured the fix: a
    /// 1 pt trailing gap stops the list touching the edge, so its collection
    /// view ends at the bar with no trailing safe area (381 pt, not 466 pt).
    /// Padding by the bar's full width doesn't work — the list then touches
    /// the safe-area edge again and is stretched back. No-op without a bar.
    func staysClearOfTrailingBar() -> some View {
        modifier(TrailingBarClearance())
    }
}

private struct TrailingBarClearance: ViewModifier {
    @State private var hasTrailingInset = false

    func body(content: Content) -> some View {
        ZStack {
            // Reads the container's trailing safe area; its own frame never
            // depends on the gap below, so the reading is stable.
            Color.clear
                .onGeometryChange(for: Bool.self) {
                    $0.safeAreaInsets.trailing > 0
                } action: { hasTrailingInset = $0 }
            content
                .padding(.trailing, hasTrailingInset ? 1 : 0)
        }
    }
}
