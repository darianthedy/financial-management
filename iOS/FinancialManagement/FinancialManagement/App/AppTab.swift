import SwiftUI

/// The root tabs (iPhone Duo design §3.1, implementation plan D1.1).
///
/// Compact width (iPhone, the Duo's outer display, narrow Split View) shows the
/// four primary tabs plus **More**. Regular width (the inner display, iPad)
/// replaces More with its destinations, promoted into the sidebar. The raw
/// values are persisted in `@SceneStorage`, so don't rename them.
enum AppTab: String, CaseIterable, Hashable {
    case dashboard
    case accounts
    case transactions
    case budgets
    /// Compact only.
    case more
    // Regular only: More's destinations, promoted into the sidebar.
    case tags
    case categories
    case fixedExpenses
    case scheduled
    case settings

    static let primary: [AppTab] = [.dashboard, .accounts, .transactions, .budgets]

    /// The tabs shown at a size class, in order. `nil` (unknown) counts as compact.
    static func visible(for sizeClass: UserInterfaceSizeClass?) -> [AppTab] {
        sizeClass == .regular
            ? primary + MoreDestination.allCases.map(\.tab)
            : primary + [.more]
    }

    func isVisible(for sizeClass: UserInterfaceSizeClass?) -> Bool {
        Self.visible(for: sizeClass).contains(self)
    }

    /// The More destination this tab stands for, if it is a sidebar-only tab.
    var moreDestination: MoreDestination? {
        MoreDestination.allCases.first { $0.tab == self }
    }
}

/// A screen reached from the More tab on compact width. On regular width each
/// one is its own sidebar tab (`tab`).
enum MoreDestination: String, CaseIterable, Hashable {
    case tags
    case categories
    case fixedExpenses
    case scheduled
    case settings

    var tab: AppTab {
        switch self {
        case .tags: .tags
        case .categories: .categories
        case .fixedExpenses: .fixedExpenses
        case .scheduled: .scheduled
        case .settings: .settings
        }
    }
}

/// Where the root is: the selected tab plus, on compact width, what is pushed
/// on More's stack.
struct TabRoute: Equatable {
    var tab: AppTab
    var morePath: [MoreDestination] = []

    /// The equivalent route after a size-class change (fold / unfold, Split
    /// View resize) — the continuity rule in design §3.1:
    /// - compact: a sidebar-only tab becomes More with that screen pushed;
    /// - regular: More becomes the tab of the screen pushed on it (or the first
    ///   Management tab when nothing is pushed), and More's stack is cleared.
    /// Primary tabs never change.
    func resolved(for sizeClass: UserInterfaceSizeClass?) -> TabRoute {
        if sizeClass == .regular {
            guard tab == .more else { return TabRoute(tab: tab) }
            return TabRoute(tab: (morePath.first ?? MoreDestination.allCases[0]).tab)
        } else {
            guard let destination = tab.moreDestination else { return self }
            return TabRoute(tab: .more, morePath: [destination])
        }
    }
}
