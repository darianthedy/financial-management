import SwiftUI

// iOS 27.1 (iPhone Duo) API shims — docs/ios-iphone-duo-implementation-plan.md D0.2.
//
// The deployment target stays iOS 26.1, so every Duo API is called through one
// of these wrappers, each behind `#available(iOS 27.1, *)` with a fallback that
// keeps today's behaviour. Feature code never writes `#available` itself.

// MARK: - Toolbar visibility priority

/// Mirrors `ToolbarItemVisibilityPriority` so call sites compile on iOS 26.
enum DuoToolbarPriority {
    case low
    case high
}

extension ToolbarContent {
    /// Keeps important items (e.g. Add) on the iPhone Duo's vertical toolbar
    /// rail while others overflow into "…". No-op before iOS 27.1.
    @ToolbarContentBuilder
    func duoVisibilityPriority(_ priority: DuoToolbarPriority) -> some ToolbarContent {
        if #available(iOS 27.1, *) {
            self.visibilityPriority(priority == .high ? .high : .low)
        } else {
            self
        }
    }
}

// MARK: - Tab bar placement

extension View {
    /// Opts a `.sidebarAdaptable` `TabView` into the sidebar on regular width.
    /// No-op before iOS 27.1.
    @ViewBuilder
    func duoSidebarTabPlacement() -> some View {
        if #available(iOS 27.1, *) {
            defaultTabBarPlacement(.sidebar)
        } else {
            self
        }
    }
}

// MARK: - Vertical bar

extension View {
    /// Keeps this stack's toolbar horizontal instead of the iPhone Duo's
    /// vertical bar. A tiled split's list column needs it: in landscape on the
    /// inner display its toolbar became a vertical capsule that reserved a
    /// ~84 pt strip at the column's trailing edge, cutting its rows short
    /// (device test, builds 143–148). No-op before iOS 27.1.
    ///
    /// UIKit forwards the preference up to the window, so this may turn the
    /// whole window's bars horizontal while a split is tiled.
    @ViewBuilder
    func duoHorizontalToolbar() -> some View {
        if #available(iOS 27.1, *) {
            toolbarVerticalBehavior(.disabled)
        } else {
            self
        }
    }
}

// MARK: - Fold context

/// Where the iPhone Duo's fold (the `.division` reserved region) crosses the
/// current view, in that view's local coordinates.
///
/// - `book`: the device is open like a book; the fold runs top-to-bottom at `divisionX`.
/// - `tent`: the fold runs left-to-right at `divisionY` (tent / laptop posture).
enum FoldContext: Equatable {
    case none
    case book(divisionX: CGFloat)
    case tent(divisionY: CGFloat)

    /// Maps division-region frames (local coordinates) to a context. Regions
    /// that miss `bounds` are ignored; a region taller than wide is a book
    /// fold, wider than tall a tent fold. Pure, so it is unit-tested directly.
    static func from(divisionFrames: [CGRect], in bounds: CGRect) -> FoldContext {
        guard let fold = divisionFrames
            .filter({ !$0.isNull && $0.insetBy(dx: -0.5, dy: -0.5).intersects(bounds) })
            .max(by: { $0.width * $0.height < $1.width * $1.height })
        else { return .none }

        if fold.height >= fold.width {
            return .book(divisionX: fold.midX - bounds.minX)
        } else {
            return .tent(divisionY: fold.midY - bounds.minY)
        }
    }

    /// The local rect the fold occupies, for overlap assertions. A zero-width
    /// line when the region has no thickness.
    func divisionRect(in size: CGSize) -> CGRect? {
        switch self {
        case .none: nil
        case .book(let x): CGRect(x: x, y: 0, width: 0, height: size.height)
        case .tent(let y): CGRect(x: 0, y: y, width: size.width, height: 0)
        }
    }
}

extension EnvironmentValues {
    /// The fold position for this view tree. Set by `.readsFoldContext()` at
    /// the root, or injected directly by layout tests.
    @Entry var foldContext: FoldContext = .none

    /// The device's active division regions in global coordinates, from the
    /// outermost `.readsFoldContext()`, for any reader below it. The region
    /// API's results below the root are unproven (the probe could only see
    /// them at the root), and it keeps one source of truth. Layout tests inject
    /// a fold here. Nil above the outermost reader.
    @Entry var foldDivisionFrames: [CGRect]? = nil
}

extension View {
    /// Measures the fold at this view and publishes it as `\.foldContext`, in
    /// this view's coordinates, to its descendants. Re-measures when the view
    /// moves or resizes and on every hinge change. A view that doesn't start at
    /// the root's origin (e.g. a tab beside the sidebar) needs its own reader.
    /// Always `.none` before iOS 27.1, and while `AdaptiveLayout` is off, so
    /// the kill switch also keeps fold layouts away from TestFlight.
    func readsFoldContext() -> some View {
        modifier(FoldContextReader())
    }
}

private struct FoldContextReader: ViewModifier {
    @State private var context: FoldContext = .none
    @State private var measured: [CGRect] = []
    @State private var hingeTick = 0
    @Environment(\.foldDivisionFrames) private var inherited

    func body(content: Content) -> some View {
        content
            .environment(\.foldContext, context)
            .environment(\.foldDivisionFrames, inherited ?? measured)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { update(geo) }
                        .onChange(of: geo.frame(in: .global)) { update(geo) }
                        .onChange(of: hingeTick) { update(geo) }
                        .onChange(of: inherited) { update(geo) }
                }
            }
            .modifier(HingeTicker(tick: $hingeTick))
    }

    private func update(_ geo: GeometryProxy) {
        let frame = geo.frame(in: .global)
        let global = inherited ?? activeDivisions(geo).map { $0.offsetBy(dx: frame.minX, dy: frame.minY) }
        if inherited == nil, global != measured { measured = global }

        let local = global.map { $0.offsetBy(dx: -frame.minX, dy: -frame.minY) }
        let next = FoldContext.from(divisionFrames: local, in: CGRect(origin: .zero, size: frame.size))
        if next != context { context = next }
    }

    /// Frames in `geo`'s own coordinates: the probe found SwiftUI's regions are
    /// already local, unlike UIKit's (a root at x 84 reports a region at -84
    /// that `UIWindow` reports at 0).
    private func activeDivisions(_ geo: GeometryProxy) -> [CGRect] {
        guard AdaptiveLayout.isEnabled, #available(iOS 27.1, *) else { return [] }
        return geo.reservedRegions(kind: .division).map(\.frame)
    }
}

/// Bumps `tick` whenever the hinge changes, so the reader re-measures even when
/// the view's size doesn't change (e.g. flat → book on the inner display).
private struct HingeTicker: ViewModifier {
    @Binding var tick: Int

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, _ in tick &+= 1 }
        } else {
            content
        }
    }
}
