// PROTOTYPE(sidebar-b1): throwaway. Delete this file and every line tagged
// `PROTOTYPE(sidebar-b1)` (`grep -rn "PROTOTYPE(sidebar-b1)" iOS`) once option
// B1 (a Notes-style root) is decided.
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

struct SidebarPrototypeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var section: PrototypeSection? = .transactions
    @State private var item: Int?
    @State private var visibility: NavigationSplitViewVisibility = .automatic
    @State private var style: PrototypeStyle = .automatic

    var body: some View {
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
                Button("Close Prototype", systemImage: "xmark.circle") { dismiss() }
            }
        }
        .navigationTitle("Prototype")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Split Style", systemImage: "ellipsis") {
                    Picker("Split Style", selection: $style) {
                        ForEach(PrototypeStyle.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
            }
        }
    }

    private func row(_ section: PrototypeSection) -> some View {
        Label(section.rawValue, systemImage: section.systemImage).tag(section)
    }

    private var list: some View {
        List(selection: $item) {
            ForEach(1...20, id: \.self) { index in
                Text("\(section?.rawValue ?? "") \(index)").tag(index)
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

private enum PrototypeStyle: String, CaseIterable, Identifiable {
    case automatic = "Automatic", balanced = "Balanced", prominentDetail = "Prominent Detail"
    var id: Self { self }
}

private extension View {
    @ViewBuilder
    func prototypeSplitStyle(_ style: PrototypeStyle) -> some View {
        switch style {
        case .automatic: navigationSplitViewStyle(.automatic)
        case .balanced: navigationSplitViewStyle(.balanced)
        case .prominentDetail: navigationSplitViewStyle(.prominentDetail)
        }
    }
}
