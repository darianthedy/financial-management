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
}

extension EnvironmentValues {
    /// Absent (e.g. in a hosted test), a screen keeps its own model.
    @Entry var foldKeptModels: FoldKeptModels? = nil
}
