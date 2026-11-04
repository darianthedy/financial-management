import SwiftUI
import UIKit

// The root `TabView`'s sidebar on regular width (the inner display, iPad).
//
// Shown, it floats over every tab's content as Notes' sidebar does: the screen
// keeps its full width under it, dimmed, and a tap on the dimming hides it.
// The system only reports the floating sidebar as the leading safe area, so
// left alone each screen narrowed itself beside it instead. SwiftUI's
// `ignoresSafeArea` doesn't reach the UIKit containers (split, stack) inside
// a tab, so `TabSidebarBridge` cancels the inset on those too.

/// Shows or hides the sidebar through the `UITabBarController` behind the
/// `TabView`, which SwiftUI gives no binding for.
@MainActor
final class TabSidebar {
    fileprivate weak var controller: UITabBarController?

    func show() { controller?.sidebar.isHidden = false }
    func hide() { controller?.sidebar.isHidden = true }
}

extension EnvironmentValues {
    /// Set by `.floatsTabSidebar()` on each tab's root.
    @Entry var tabSidebar: TabSidebar? = nil
}

enum FloatingTabSidebar {
    /// A leading safe area this wide is the sidebar floating over the content,
    /// not a hardware inset.
    static let minimumWidth: CGFloat = 200

    /// How much of the leading safe area is the floating sidebar, which the
    /// content lays out under rather than beside: 0 while it is hidden, and
    /// always on compact width, which has no sidebar.
    static func width(leadingInset: CGFloat, sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        guard sizeClass == .regular, leadingInset >= minimumWidth else { return 0 }
        return leadingInset
    }
}

extension View {
    /// Lets the tab sidebar float over this tab root, dimming it while shown.
    /// No-op on compact width.
    func floatsTabSidebar() -> some View {
        modifier(FloatsTabSidebar())
    }
}

private struct FloatsTabSidebar: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var sidebar = TabSidebar()

    func body(content: Content) -> some View {
        // A reader in both size classes, so a fold doesn't re-create the tab.
        GeometryReader { geo in
            let width = FloatingTabSidebar.width(
                leadingInset: geo.safeAreaInsets.leading, sizeClass: horizontalSizeClass
            )
            content
                .environment(\.tabSidebar, sidebar)
                .ignoresSafeArea(.container, edges: width > 0 ? .leading : [])
                .overlay {
                    if width > 0 {
                        SidebarDimming { sidebar.hide() }
                            .ignoresSafeArea()
                            .transition(.opacity)
                    }
                }
                .animation(.default, value: width > 0)
                .background { TabSidebarBridge(sidebar: sidebar, overlap: width) }
        }
    }
}

/// Dims the content under the floating sidebar; a tap hides the sidebar.
private struct SidebarDimming: View {
    let hide: () -> Void

    var body: some View {
        Rectangle()
            .fill(.black.opacity(0.3))
            .onTapGesture(perform: hide)
            .accessibilityElement()
            .accessibilityLabel("Hide Sidebar")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, hide)
    }
}

/// Shows the sidebar from a tiled split, which has no tab `NavigationStack`
/// bar for the sidebar's own toggle. Hiding it is the dimming's tap, or the
/// sidebar's own button.
struct TabSidebarToggle: View {
    @Environment(\.tabSidebar) private var sidebar

    var body: some View {
        if let sidebar {
            Button { sidebar.show() } label: {
                Label("Show Sidebar", systemImage: "sidebar.left")
            }
        }
    }
}

/// The UIKit side of `.floatsTabSidebar()`.
///
/// It finds the `UITabBarController` for `TabSidebar`. It also cancels the
/// sidebar's inset on the UIKit containers inside the tab, such as the split's
/// `UISplitViewController` or a `NavigationStack`'s navigation controller.
/// `ignoresSafeArea` moves their frames under the sidebar, but they take
/// their safe area from UIKit, so the columns and bars stayed beside the
/// sidebar (device test, TestFlight build from this branch).
private struct TabSidebarBridge: UIViewRepresentable {
    let sidebar: TabSidebar
    let overlap: CGFloat

    func makeUIView(context: Context) -> BridgeView {
        let view = BridgeView()
        view.isUserInteractionEnabled = false
        view.sidebar = sidebar
        view.overlap = overlap
        return view
    }

    func updateUIView(_ uiView: BridgeView, context: Context) {
        uiView.sidebar = sidebar
        uiView.overlap = overlap
        uiView.apply()
    }

    final class BridgeView: UIView {
        weak var sidebar: TabSidebar?
        var overlap: CGFloat = 0
        /// The inset applied to each container, so only those are reset.
        private var applied: [ObjectIdentifier: CGFloat] = [:]

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            sidebar?.controller = nearest(UITabBarController.self)
            apply()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            apply()
        }

        /// Sets each container's leading additional safe area to minus the
        /// overlap, which cancels the sidebar's inset and leaves the rest.
        func apply() {
            // The tab's own hosting controller: its children are the containers.
            guard window != nil, let tabRoot = nearest(UIViewController.self) else { return }
            for child in tabRoot.children {
                let key = ObjectIdentifier(child)
                let wanted = -overlap
                if overlap == 0 && applied[key] == nil { continue }
                if child.additionalSafeAreaInsets.left != wanted {
                    child.additionalSafeAreaInsets.left = wanted
                }
                applied[key] = overlap == 0 ? nil : wanted
            }
        }

        private func nearest<T>(_ type: T.Type) -> T? {
            var responder: UIResponder? = next
            while let current = responder {
                if let match = current as? T { return match }
                responder = current.next
            }
            return nil
        }
    }
}
