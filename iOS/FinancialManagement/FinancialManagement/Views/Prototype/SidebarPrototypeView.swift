// PROTOTYPE(sidebar-b1): throwaway. Delete this file and every line tagged
// `PROTOTYPE(sidebar-b1)` (`grep -rn "PROTOTYPE(sidebar-b1)" iOS`) once option
// B1 (a Notes-style root) is decided.
//
// On: Settings › Open Sidebar Prototype swaps the app's root for this
// (`ContentRootView`), as B1 would; "Close Prototype" swaps it back.
//
// Checks on the device, before the rewrite, how a three-column
// `NavigationSplitView` root behaves: sidebar | list | detail, as in Notes.
// - Inner display, landscape: does the sidebar slide over the list and detail
//   (Notes), or push them aside? Try each split style from the "…" menu.
// - Inner display, portrait, and Split View.
// - Outer display (fold with it open): does it collapse into one stack,
//   Sections → list → detail, as Notes does?
// - Dashboard and Settings have no list: they swap to a two-column split
//   (sidebar | screen). Is the swap acceptable?

import SwiftUI
import UIKit

enum SidebarPrototype {
    /// On: the prototype replaces the app's root, so it survives a fold.
    static let storageKey = "prototype.sidebarB1"
}

struct SidebarPrototypeView: View {
    @AppStorage(SidebarPrototype.storageKey) private var isOn = false
    @SceneStorage("prototype.rowStyle") private var rowStyle: PrototypeRowStyle = .selection
    @State private var section: PrototypeSection? = .transactions
    @State private var item: Int?
    @State private var visibility: NavigationSplitViewVisibility = .automatic
    @SceneStorage("prototype.style.v2") private var style: PrototypeStyle = .notes

    @State private var landscape = true

    var body: some View {
        splits
            .background { SplitBehaviorBridge(behavior: style == .notes ? (landscape ? .displace : .overlay) : nil) }
            .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height } action: { landscape = $0 }
            .onChange(of: landscape, initial: true) { applyNotesVisibility() }
            .onChange(of: style) { applyNotesVisibility() }
    }

    /// Notes: list | detail in landscape, the detail alone in portrait.
    private func applyNotesVisibility() {
        guard style == .notes else { return }
        visibility = landscape ? .doubleColumn : .automatic
    }

    private var splits: some View {
        Group {
            if section?.hasList ?? true {
                NavigationSplitView(columnVisibility: $visibility) {
                    sidebar
                } content: {
                    list
                } detail: {
                    detail
                }
            } else {
                NavigationSplitView(columnVisibility: $visibility) {
                    sidebar
                } detail: {
                    NavigationStack { screen }
                }
            }
        }
        .prototypeSplitStyle(style)
        .onChange(of: section) { item = nil }
    }

    private var sidebar: some View {
        List(selection: $section) {
            Section {
                ForEach(PrototypeSection.primary) { row($0) }
            }
            Section("Management") {
                ForEach(PrototypeSection.management) { row($0) }
            }
            Section {
                Button("Close Prototype", systemImage: "xmark.circle") { isOn = false }
            }
        }
        .navigationTitle("Prototype")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Prototype Options", systemImage: "ellipsis") {
                    Picker("Split Style", selection: $style) {
                        ForEach(PrototypeStyle.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Rows", selection: $rowStyle) {
                        ForEach(PrototypeRowStyle.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ section: PrototypeSection) -> some View {
        switch rowStyle {
        case .selection:
            Label(section.rawValue, systemImage: section.systemImage).tag(section)
        case .buttons:
            Button { self.section = section } label: {
                Label(section.rawValue, systemImage: section.systemImage)
            }
            .listRowBackground(self.section == section ? Color.accentColor.opacity(0.2) : nil)
        }
    }

    private var list: some View {
        List(selection: $item) {
            ForEach(1...20, id: \.self) { index in
                switch rowStyle {
                case .selection:
                    Text("\(section?.rawValue ?? "") \(index)").tag(index)
                case .buttons:
                    Button("\(section?.rawValue ?? "") \(index)") { item = index }
                        .listRowBackground(item == index ? Color.accentColor.opacity(0.2) : nil)
                }
            }
        }
        .navigationTitle(section?.rawValue ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") {}
            }
        }
    }

    private var detail: some View {
        Group {
            if let item {
                List {
                    Text("Detail of \(section?.rawValue ?? "") \(item)")
                    Text("Style: \(style.rawValue)")
                }
                .navigationTitle("\(section?.rawValue ?? "") \(item)")
            } else {
                ContentUnavailableView("Select an Item", systemImage: section?.systemImage ?? "square")
            }
        }
    }

    private var screen: some View {
        List {
            Text("\(section?.rawValue ?? "") placeholder (no list column)")
            Text("Style: \(style.rawValue)")
        }
        .navigationTitle(section?.rawValue ?? "")
    }
}

private enum PrototypeSection: String, Identifiable, Hashable {
    case dashboard = "Dashboard", accounts = "Accounts", transactions = "Transactions", budgets = "Budgets"
    case tags = "Tags", categories = "Categories", fixedExpenses = "Fixed Expenses"
    case scheduled = "Scheduled", settings = "Settings"

    static let primary: [Self] = [.dashboard, .accounts, .transactions, .budgets]
    static let management: [Self] = [.tags, .categories, .fixedExpenses, .scheduled, .settings]

    var id: Self { self }
    var hasList: Bool { self != .dashboard && self != .settings }

    var systemImage: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .accounts: "wallet.bifold"
        case .transactions: "arrow.left.arrow.right"
        case .budgets: "target"
        case .tags, .categories: "tag"
        case .fixedExpenses: "receipt"
        case .scheduled: "calendar.badge.clock"
        case .settings: "gear"
        }
    }
}

/// The broken inner-display lists (build from this branch): selection rows
/// vs plain buttons, to tell a selection bug from a layout one.
private enum PrototypeRowStyle: String, CaseIterable, Identifiable {
    case selection = "Selection", buttons = "Buttons"
    var id: Self { self }
}

private enum PrototypeStyle: String, CaseIterable, Identifiable {
    case notes = "Notes (UIKit displace)"
    case automatic = "Automatic", balanced = "Balanced", prominentDetail = "Prominent Detail"
    var id: Self { self }
}

private extension View {
    @ViewBuilder
    func prototypeSplitStyle(_ style: PrototypeStyle) -> some View {
        switch style {
        case .automatic, .notes: navigationSplitViewStyle(.automatic)
        case .balanced: navigationSplitViewStyle(.balanced)
        case .prominentDetail: navigationSplitViewStyle(.prominentDetail)
        }
    }
}

/// Sets the `UISplitViewController` behind a `NavigationSplitView` to `behavior`,
/// which SwiftUI's split styles can't express: `.displace` is Notes in
/// landscape (list beside the detail; the sidebar pushes them, dimming the
/// detail), `.overlay` Notes in portrait. Nil leaves SwiftUI's choice.
private struct SplitBehaviorBridge: UIViewRepresentable {
    let behavior: UISplitViewController.SplitBehavior?

    func makeUIView(context: Context) -> BridgeView {
        let view = BridgeView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: BridgeView, context: Context) {
        uiView.behavior = behavior
        uiView.apply()
    }

    final class BridgeView: UIView {
        var behavior: UISplitViewController.SplitBehavior?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            apply()
        }

        func apply() {
            guard let behavior, window != nil, let split = splitViewController() else { return }
            if split.preferredSplitBehavior != behavior { split.preferredSplitBehavior = behavior }
        }

        /// The split is below this view (the view backs the whole root), so
        /// search the window's controllers rather than the responder chain.
        private func splitViewController() -> UISplitViewController? {
            var queue: [UIViewController] = window?.rootViewController.map { [$0] } ?? []
            while !queue.isEmpty {
                let controller = queue.removeFirst()
                if let split = controller as? UISplitViewController { return split }
                queue += controller.children
                if let presented = controller.presentedViewController { queue.append(presented) }
            }
            return nil
        }
    }
}
