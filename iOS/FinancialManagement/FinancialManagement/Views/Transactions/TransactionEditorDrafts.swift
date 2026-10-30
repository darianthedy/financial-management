import SwiftUI

/// The draft of the transaction being edited in the Transactions detail column
/// (iPhone Duo plan D3.1).
///
/// A fold / unfold swaps the containers around the Transactions list
/// (`SplitRootContainer`, `.splitDetail`), which re-creates the list and its
/// embedded form. The form's view model is therefore kept here, owned by
/// `ContentRootView` above every size-class branch, so unsaved edits survive:
/// the tiled detail column and the compact push both ask for the same model.
///
/// A cache, not view state: nothing here is observed, so asking for a model
/// while a body is evaluated never invalidates that body.
@MainActor
final class TransactionEditorDrafts {
    /// The transaction the draft edits, as it was when editing began.
    private(set) var transaction: Transaction?
    private var model: TransactionFormViewModel?

    /// The draft for `transaction`, started on first use and kept (edits and
    /// all) until another transaction is edited or `discard()` is called.
    func model(
        for transaction: Transaction, currency: String, decimalPlaces: Int
    ) -> TransactionFormViewModel {
        if let model, self.transaction?.id == transaction.id { return model }
        let started = TransactionFormViewModel(
            editing: transaction, currency: currency, decimalPlaces: decimalPlaces
        )
        self.transaction = transaction
        model = started
        return started
    }

    /// The draft's transaction, when it is `id`. Lets the detail column keep
    /// showing a draft whose row isn't in the loaded page (e.g. after a fold
    /// re-creates the list, which reloads from its first page).
    func transaction(withId id: UUID) -> Transaction? {
        transaction?.id == id ? transaction : nil
    }

    /// Drops the draft (saved, cancelled, discarded or deselected).
    func discard() {
        transaction = nil
        model = nil
    }
}

extension EnvironmentValues {
    /// Set by `ContentRootView`. Absent (e.g. in a hosted test), the
    /// Transactions list keeps its own drafts.
    @Entry var transactionDrafts: TransactionEditorDrafts? = nil
}
