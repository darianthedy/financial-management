import SwiftUI

/// Places content clear of the iPhone Duo's fold (implementation plan D6.1).
///
/// - **Two children, flat:** stacked with `spacing`, like a `VStack`.
/// - **Two children, folded:** one per region: leading and trailing in book
///   posture, top and bottom in tent. Each is centered in its region; below the
///   fold the second child starts at the fold, so a scroll view can extend it.
/// - **One child:** centered, in the trailing region in book posture or the top
///   region in tent (design doc S1). It needs a proposed height, as in a `ZStack`.
///
/// Each child is `maxChildWidth` wide at most, inside `margin` on both sides.
///
/// In a scroll view, which proposes no height, pass the visible height as
/// `minimumHeight`: folded, the regions are then centered in what's on screen
/// rather than pinned to its top edge. The layout still grows past it to fit.
struct FoldRegions: Layout {
    var fold: FoldContext
    var spacing: CGFloat = 16
    var margin: CGFloat = 16
    var maxChildWidth: CGFloat = .infinity
    var minimumHeight: CGFloat = 0

    private struct Placement {
        var frames: [CGRect]
        var size: CGSize
    }

    private func placement(proposal: ProposedViewSize, subviews: Subviews) -> Placement {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let height = proposal.height ?? (minimumHeight > 0 ? minimumHeight : nil)
        switch fold {
        case .book(let x) where x > 0 && x < width:
            return book(foldX: x, width: width, height: height, subviews: subviews)
        case .tent(let y) where y > 0 && y < height ?? .infinity:
            return tent(foldY: y, width: width, height: height, subviews: subviews)
        default:
            // Flat keeps today's top-down column.
            return flat(width: width, height: proposal.height, subviews: subviews)
        }
    }

    private func childWidth(in available: CGFloat) -> CGFloat {
        max(0, min(maxChildWidth, available - margin * 2))
    }

    private func size(_ subview: LayoutSubview, width: CGFloat) -> CGSize {
        let fitted = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
        return CGSize(width: min(fitted.width, width), height: fitted.height)
    }

    private func centered(_ child: CGSize, inWidth rect: CGRect, y: CGFloat) -> CGRect {
        CGRect(x: rect.midX - child.width / 2, y: y, width: child.width, height: child.height)
    }

    private func flat(width: CGFloat, height: CGFloat?, subviews: Subviews) -> Placement {
        let sizes = subviews.map { size($0, width: childWidth(in: width)) }
        let total = sizes.map(\.height).reduce(0, +) + spacing * CGFloat(max(sizes.count - 1, 0))
        let container = CGRect(x: 0, y: 0, width: width, height: height ?? total)
        // Top-down in a scroll view; centered when given a height.
        var y = subviews.count == 1 ? max(0, (container.height - total) / 2) : 0
        var frames: [CGRect] = []
        for child in sizes {
            frames.append(centered(child, inWidth: container, y: y))
            y += child.height + spacing
        }
        return Placement(frames: frames, size: CGSize(width: width, height: height ?? total))
    }

    /// One child per region, centered against each other.
    private func book(foldX: CGFloat, width: CGFloat, height: CGFloat?, subviews: Subviews) -> Placement {
        let leading = CGRect(x: 0, y: 0, width: foldX, height: 0)
        let trailing = CGRect(x: foldX, y: 0, width: width - foldX, height: 0)
        let regions = subviews.count == 1 ? [trailing] : [leading, trailing]
        let sizes = zip(subviews, regions).map { size($0, width: childWidth(in: $1.width)) }
        let tallest = sizes.map(\.height).max() ?? 0
        let full = max(height ?? 0, tallest)
        let frames = zip(sizes, regions).map { child, region in
            centered(child, inWidth: region, y: max(0, (full - child.height) / 2))
        }
        return Placement(frames: frames, size: CGSize(width: width, height: full))
    }

    private func tent(foldY: CGFloat, width: CGFloat, height: CGFloat?, subviews: Subviews) -> Placement {
        let container = CGRect(x: 0, y: 0, width: width, height: 0)
        let sizes = subviews.map { size($0, width: childWidth(in: width)) }
        var frames: [CGRect] = []
        if let top = sizes.first {
            frames.append(centered(top, inWidth: container, y: max(0, (foldY - top.height) / 2)))
        }
        var bottomEdge = frames.first?.maxY ?? 0
        if sizes.count > 1 {
            let below = height.map { max(0, $0 - foldY) } ?? 0
            let y = foldY + max(margin, (below - sizes[1].height) / 2)
            frames.append(centered(sizes[1], inWidth: container, y: y))
            bottomEdge = y + sizes[1].height + margin
        }
        return Placement(frames: frames, size: CGSize(width: width, height: max(height ?? 0, bottomEdge)))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        placement(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = placement(
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews
        ).frames
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }
}
