import SwiftUI

// Tent posture (iPhone Duo plan D6.2): read-only glance content above the fold,
// the controls and list below it.
//
// This is a `Layout` rather than `ArrangementView`, which the plan named: that
// view reads the device's real hinge, so a layout test can't inject a fold, and
// CI can't reach a real one. Driving the split from `FoldContext` keeps it tested
// on every PR, and keeps the screen's identity (its scroll position, its state)
// when the posture changes.

extension EnvironmentValues {
    /// True below a tent glance, so a screen can drop what the glance now shows.
    @Entry var isBelowTentGlance = false
}

extension View {
    /// In tent posture on regular width, shows `glance` above the fold and this
    /// view below it. Otherwise this view alone, unchanged. Apply it outermost
    /// on a screen, so the list, its toolbar and its sheets stay on the view.
    func tentGlance<Glance: View>(@ViewBuilder _ glance: () -> Glance) -> some View {
        TentGlanceContainer(glance: glance(), content: self).readsFoldContext()
    }
}

private struct TentGlanceContainer<Glance: View, Content: View>: View {
    let glance: Glance
    let content: Content

    @Environment(\.foldContext) private var fold
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var foldY: CGFloat? {
        guard horizontalSizeClass == .regular, case .tent(let y) = fold else { return nil }
        return y
    }

    var body: some View {
        TentSplit(foldY: foldY) {
            if foldY != nil {
                glance
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .layoutProbe("tent.glance")
                    .clipped()
            }
            // A stable position, so the screen keeps its state as the glance
            // comes and goes.
            content.environment(\.isBelowTentGlance, foldY != nil)
        }
        // The scroll view now starts below the fold, away from the bar, and the
        // Dashboard lost its large title there (device test, build 143). Inline
        // keeps it in the bar. Screens whose stacks sit below the glance (the
        // tiled splits) keep their own titles.
        .navigationBarTitleDisplayMode(foldY != nil ? .inline : .automatic)
    }
}

/// Fills its space with the last child; with a fold and two children, the first
/// goes above the fold and the last below it, each `margin` clear.
struct TentSplit: Layout {
    var foldY: CGFloat?
    var margin: CGFloat = 16

    /// The regions of `size`, or nil when `foldY` doesn't cross it. Pure, so it
    /// is unit-tested directly.
    static func regions(
        in size: CGSize, foldY: CGFloat?, margin: CGFloat
    ) -> (glance: CGRect, main: CGRect)? {
        guard let foldY, foldY > margin, foldY < size.height - margin else { return nil }
        return (
            CGRect(x: 0, y: 0, width: size.width, height: foldY - margin),
            CGRect(x: 0, y: foldY + margin, width: size.width, height: size.height - foldY - margin)
        )
    }

    /// Centers a glance of `height` in `region`; a taller one keeps its top
    /// and is clipped at the region's edge, so it can't reach the fold.
    static func centered(height: CGFloat, in region: CGRect) -> CGRect {
        let fitted = min(height, region.height)
        return CGRect(
            x: region.minX, y: region.minY + (region.height - fitted) / 2,
            width: region.width, height: fitted
        )
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        func place(_ subview: LayoutSubview, in rect: CGRect) {
            subview.place(
                at: CGPoint(x: bounds.minX + rect.minX, y: bounds.minY + rect.minY),
                proposal: ProposedViewSize(width: rect.width, height: rect.height)
            )
        }
        guard let main = subviews.last else { return }
        let whole = CGRect(origin: .zero, size: bounds.size)
        if subviews.count == 2, let regions = Self.regions(in: bounds.size, foldY: foldY, margin: margin) {
            let height = subviews[0].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
            place(subviews[0], in: Self.centered(height: height, in: regions.glance))
            place(main, in: regions.main)
        } else {
            // A glance with no room is parked at zero size.
            if subviews.count == 2 { place(subviews[0], in: .zero) }
            place(main, in: whole)
        }
    }
}

/// A row of labelled figures for a tent glance.
struct GlanceStats: View {
    struct Stat: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    let stats: [Stat]

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 4) {
                    Text(stat.label)
                        .font(.caption)
                        .foregroundStyle(Color.appMutedForeground)
                    Text(stat.value)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.appForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
