import SwiftUI

/// The root's sections, listed in its sidebar (iPhone Duo design §3.1, as in
/// Notes): the primary screens, then Management. Order, labels and icons mirror
/// web's nav-config.ts. The raw values are persisted in `@SceneStorage` (they
/// match the former tabs'), so don't rename them.
enum AppSection: String, CaseIterable, Hashable, Identifiable {
    case dashboard
    case accounts
    case transactions
    case budgets
    case tags
    case categories
    case fixedExpenses
    case scheduled
    case settings

    static let primary: [AppSection] = [.dashboard, .accounts, .transactions, .budgets]
    /// Settings closes the Management section, as in the mockups.
    static let management: [AppSection] = [.tags, .categories, .fixedExpenses, .scheduled, .settings]

    var id: Self { self }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .accounts: "Accounts"
        case .transactions: "Transactions"
        case .budgets: "Budgets"
        case .tags: "Tags"
        case .categories: "Categories"
        case .fixedExpenses: "Fixed Expenses"
        // label matches nav-config ("Scheduled")
        case .scheduled: "Scheduled"
        case .settings: "Settings"
        }
    }

    /// SF Symbols chosen to match each Lucide icon on web.
    var systemImage: String {
        switch self {
        // web LayoutDashboard (grid)
        case .dashboard: "square.grid.2x2"
        // web Wallet
        case .accounts: "wallet.bifold"
        // web ArrowLeftRight
        case .transactions: "arrow.left.arrow.right"
        // web PiggyBank (no SF piggy-bank symbol; target reads as a budget goal)
        case .budgets: "target"
        // web Tag
        case .tags, .categories: "tag"
        // web Receipt
        case .fixedExpenses: "receipt"
        // web CalendarClock
        case .scheduled: "calendar.badge.clock"
        case .settings: "gear"
        }
    }

    /// Whether the section is a list → detail screen, shown as the root's list
    /// and detail columns. Dashboard and Settings fill the detail column alone.
    var hasList: Bool {
        switch self {
        case .dashboard, .settings: false
        default: true
        }
    }
}
