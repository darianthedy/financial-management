import CoreGraphics

/// The main Transactions toolbar's overflow rule (iPhone Duo plan D3.3).
///
/// On the Duo's vertical bar `primaryAction` items go last, so without a
/// priority Add is the first to fall into "…". Add is the screen's primary
/// action and keeps its place; Summary is the first to overflow. Filter keeps
/// the default, and when badged (filters active) the system overflows it last.
enum TransactionsToolbar {
    enum Item { case summary, add }

    static func priority(of item: Item) -> DuoToolbarPriority {
        switch item {
        case .add: .high
        case .summary: .low
        }
    }
}

/// The Filters sheet's From / To layout (D3.3): side by side in one row once
/// the sheet is wide enough (page-sized on the inner display), else one row
/// each, exactly as on iPhone.
enum FilterDateRowLayout {
    /// Two compact date pickers with their labels and the row's dot.
    static let minimumSideBySideWidth: CGFloat = 480

    static func isSideBySide(rowWidth: CGFloat) -> Bool {
        rowWidth >= minimumSideBySideWidth
    }
}
