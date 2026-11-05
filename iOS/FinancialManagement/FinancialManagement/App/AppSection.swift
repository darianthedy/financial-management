import SwiftUI

/// The app's screens: the primary ones are tabs (`RootTab`), the rest are
/// listed in More. Order, labels and icons mirror web's nav-config.ts. The raw
/// values are persisted in `@SceneStorage`, so don't rename them.
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
    /// More's Management section.
    static let management: [AppSection] = [.tags, .categories, .fixedExpenses, .scheduled]
    /// Everything More pushes: Management, then Settings.
    static let more: [AppSection] = management + [.settings]

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

    /// Whether the list takes half the split, as in Contacts: Transactions'
    /// rows keep a readable title beside their aligned amounts.
    var halvesSplit: Bool { self == .transactions }
}
