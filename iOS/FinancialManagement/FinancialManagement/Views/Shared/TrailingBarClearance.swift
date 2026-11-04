import SwiftUI

extension View {
    /// Lays a scrolling list out beside the trailing safe area (the Duo outer
    /// display's vertical bar) instead of under it. A list that runs under the
    /// bar slides a swiped row by its actions *plus* the bar's width, leaving
    /// a gap before Delete. Its rows already stop at the bar, so nothing
    /// visible moves. No-op without a trailing inset.
    func staysClearOfTrailingBar() -> some View {
        modifier(TrailingBarClearance())
    }
}

private struct TrailingBarClearance: ViewModifier {
    @State private var trailingInset: CGFloat = 0

    func body(content: Content) -> some View {
        ZStack {
            // Measures the bar: a view that reaches under it reports the
            // inset it overlaps. Kept apart from the list so the list's own
            // frame doesn't feed back into the measurement. (Measuring inside
            // the list's ignoresSafeArea, as #297 did, always read 0.)
            Color.clear
                .ignoresSafeArea(.container, edges: .trailing)
                .onGeometryChange(for: CGFloat.self) {
                    $0.safeAreaInsets.trailing
                } action: { trailingInset = $0 }
            // The list ends at the bar and has no trailing safe area left to
            // extend into.
            content
                .padding(.trailing, trailingInset)
                .ignoresSafeArea(.container, edges: .trailing)
        }
    }
}
