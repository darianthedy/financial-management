import SwiftUI

/// The Dashboard's card grid on regular width (iPhone Duo plan D4.1): two
/// balanced stacks, status cards on the left (Verdict, Cashflow, Trend) and
/// list cards on the right (Accounts, Planned, Unplanned).
///
/// The column count comes from the proposed width, not a breakpoint: two
/// columns once each can be at least `minimumColumnWidth`, else one stack in
/// declaration order (the iPhone order). Each column stacks its cards
/// top-down with `spacing`, like the `VStack` the Dashboard uses on compact.
struct DashboardColumns: Layout {
    var spacing: CGFloat = 16
    var minimumColumnWidth: CGFloat = 300

    /// 1 or 2 columns for `width`. Pure, so it is unit-tested directly.
    static func columnCount(width: CGFloat, spacing: CGFloat, minimumColumnWidth: CGFloat) -> Int {
        width >= minimumColumnWidth * 2 + spacing ? 2 : 1
    }

    private func columns(for width: CGFloat) -> Int {
        Self.columnCount(width: width, spacing: spacing, minimumColumnWidth: minimumColumnWidth)
    }

    /// Each subview's frame (origin relative to the layout) at `width`.
    private func frames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        let count = columns(for: width)
        let columnWidth = count == 2 ? (width - spacing) / 2 : width
        var nextY = [CGFloat](repeating: 0, count: count)
        return subviews.map { subview in
            let column = count == 2 ? min(max(subview[DashboardColumnKey.self], 0), 1) : 0
            let height = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
            let frame = CGRect(
                x: CGFloat(column) * (columnWidth + spacing), y: nextY[column],
                width: columnWidth, height: height
            )
            nextY[column] += height + spacing
            return frame
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width
            ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max()
            ?? 0
        let height = frames(width: width, subviews: subviews).map(\.maxY).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, frames(width: bounds.width, subviews: subviews)) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }
}

/// Which `DashboardColumns` column a card belongs to: 0 left, 1 right.
private struct DashboardColumnKey: LayoutValueKey {
    static let defaultValue = 0
}

extension View {
    /// Puts a Dashboard card in the right-hand column on regular width.
    func dashboardColumn(_ column: Int) -> some View {
        layoutValue(key: DashboardColumnKey.self, value: column)
    }
}
