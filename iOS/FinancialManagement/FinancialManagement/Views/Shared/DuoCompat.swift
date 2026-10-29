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
}

extension View {
    /// Measures the fold at this view and publishes it as `\.foldContext` to
    /// its descendants. Re-measures on resize and on every hinge change.
    /// Always `.none` before iOS 27.1.
    func readsFoldContext() -> some View {
        modifier(FoldContextReader())
    }
}

private struct FoldContextReader: ViewModifier {
    @State private var context: FoldContext = .none
    @State private var hingeTick = 0

    func body(content: Content) -> some View {
        content
            .environment(\.foldContext, context)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { update(geo) }
                        .onChange(of: geo.size) { update(geo) }
                        .onChange(of: hingeTick) { update(geo) }
                }
            }
            .modifier(HingeTicker(tick: $hingeTick))
    }

    private func update(_ geo: GeometryProxy) {
        guard #available(iOS 27.1, *) else { return }
        let origin = geo.frame(in: .global).origin
        let frames = geo.reservedRegions(kind: .division)
            .compactMap(ReservedRegionGeometry.globalFrame(of:))
            .map { $0.offsetBy(dx: -origin.x, dy: -origin.y) }
        let next = FoldContext.from(divisionFrames: frames, in: CGRect(origin: .zero, size: geo.size))
        if next != context { context = next }
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

/// Reads a `ReservedRegion`'s frame.
///
/// The iOS 27.1 SDK dump (scripts/duo-probe/sdk-apis.sh) only surfaced the
/// region's `id` and `kind`, so the public geometry accessor isn't confirmed
/// yet. Until it is, this reads the frame the probe saw in the region's
/// description — `base.frame` in window (global) coordinates, plus
/// `base.isActive` — via reflection. Returns nil for inactive regions or if the
/// shape changes, which degrades to `FoldContext.none` rather than crashing.
/// TODO(D6.1): replace with the public accessor once the SDK dump shows it.
enum ReservedRegionGeometry {
    static func globalFrame(of region: Any) -> CGRect? {
        let base = child(named: "base", of: region) ?? region
        if let active = child(named: "isActive", of: base) as? Bool, !active { return nil }
        guard let frame = child(named: "frame", of: base) else { return nil }
        if let rect = frame as? CGRect { return rect }
        // The probe printed the frame as a 4-tuple (x, y, w, h).
        let parts = Mirror(reflecting: frame).children.compactMap { child -> CGFloat? in
            switch child.value {
            case let d as Double: CGFloat(d)
            case let c as CGFloat: c
            default: nil
            }
        }
        guard parts.count == 4 else { return nil }
        return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    private static func child(named name: String, of value: Any) -> Any? {
        Mirror(reflecting: value).children.first { $0.label == name }?.value
    }
}
