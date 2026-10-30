import SwiftUI

/// View models that outlive a fold, owned by `ContentRootView`.
///
/// A fold / unfold re-creates these screens (`SplitRootContainer`, the
/// More ⇄ sidebar swap), which would reset their month to the current one and
/// strand any sheet still open on the old view model.
@MainActor
final class FoldKeptModels {
    let budgets = BudgetListViewModel()
    let fixedExpenses = FixedExpenseListViewModel()

    /// Each screen's open drill-down, so filters changed inside it survive too.
    /// A cache, not view state: nothing here is observed, so asking for a model
    /// while a body is evaluated never invalidates that body.
    private var drilldowns: [String: (item: String, model: TransactionListViewModel)] = [:]

    func drilldown(
        screen: String, item: String, filters: TransactionFilters
    ) -> TransactionListViewModel {
        if let kept = drilldowns[screen], kept.item == item { return kept.model }
        let model = TransactionListViewModel(initialFilters: filters)
        drilldowns[screen] = (item, model)
        return model
    }

    /// The user left the drill-down, so the next one starts from its own filters.
    func discardDrilldown(screen: String) {
        drilldowns[screen] = nil
    }
}

/// A screen's filtered transactions (Budgets, Categories, Tags, Fixed Expenses),
/// on a model that survives a fold. `screen` is the `.splitDetail` storage key.
struct DrilldownTransactionList: View {
    @Environment(\.foldKeptModels) private var keptModels
    let screen: String
    let item: String
    let filters: TransactionFilters

    var body: some View {
        TransactionListView(
            initialFilters: filters,
            model: keptModels?.drilldown(screen: screen, item: item, filters: filters)
        )
    }
}

extension EnvironmentValues {
    /// Absent (e.g. in a hosted test), a screen keeps its own model.
    @Entry var foldKeptModels: FoldKeptModels? = nil
}
