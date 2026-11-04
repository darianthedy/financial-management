import SwiftUI
import UIKit

// The root `TabView`'s sidebar on regular width (the inner display, iPad).
//
// Shown, it floats over every tab's content as Notes' sidebar does: the screen
// keeps its full width under it, dimmed, and a tap on the dimming hides it.
// The system only reports the floating sidebar as the leading safe area, so
// left alone each screen narrowed itself beside it instead — and a list →
// detail split, too narrow then for two columns, fell back to a stack.

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
        }
        .findsTabSidebar(sidebar)
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

extension View {
    /// Points `sidebar` at the nearest `UITabBarController` above this view
    /// once it is in a window.
    fileprivate func findsTabSidebar(_ sidebar: TabSidebar) -> some View {
        background { TabBarControllerFinder(sidebar: sidebar) }
    }
}

private struct TabBarControllerFinder: UIViewRepresentable {
    let sidebar: TabSidebar

    func makeUIView(context: Context) -> FinderView {
        let view = FinderView()
        view.isUserInteractionEnabled = false
        view.sidebar = sidebar
        return view
    }

    func updateUIView(_ uiView: FinderView, context: Context) {
        uiView.sidebar = sidebar
    }

    final class FinderView: UIView {
        weak var sidebar: TabSidebar?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            var responder: UIResponder? = self
            while let next = responder?.next {
                if let controller = next as? UITabBarController {
                    sidebar?.controller = controller
                    return
                }
                responder = next
            }
        }
    }
}
