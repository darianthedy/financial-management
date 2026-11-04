import SwiftUI

extension View {
    /// Lays a scrolling list out beside the trailing safe area (the Duo outer
    /// display's vertical bar) instead of under it. A list that runs under the
    /// bar slides its rows that much further on a swipe, so a single Delete
    /// pushed the row half off screen and left a gap. Its rows' content
    /// already stops at the bar, so nothing visible moves. No-op without a
    /// trailing inset.
    func staysClearOfTrailingBar() -> some View {
        modifier(TrailingBarClearance())
    }
}

private struct TrailingBarClearance: ViewModifier {
    @State private var trailingInset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            // The list ends at the bar, and has no trailing safe area left
            // to extend into.
            .padding(.trailing, trailingInset)
            .ignoresSafeArea(.container, edges: .trailing)
            // Read from the parent's safe area, which the ignore above
            // doesn't change.
            .background {
                Color.clear.onGeometryChange(for: CGFloat.self) {
                    $0.safeAreaInsets.trailing
                } action: { trailingInset = $0 }
            }
    }
}
