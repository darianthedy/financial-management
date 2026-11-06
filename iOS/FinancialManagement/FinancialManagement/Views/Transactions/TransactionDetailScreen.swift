import SwiftUI

/// One transaction's detail, by ID, on the list's model: what the
/// Transactions list shows beside it or pushes, and what a tab's stack opens
/// on when a fold or a rotation re-creates it on the detail
/// (`SplitRootContainer(detail:)`). Its editor works on the shared draft, so
/// the edits survive, and it reopens editing while the draft exists.
struct TransactionDetailScreen: View {
    @Environment(AppState.self) private var appState

    let id: UUID
    let model: TransactionListViewModel
    let drafts: TransactionEditorDrafts
    /// Open straight into the editor (the row menu's Edit).
    var startsEditing = false
    /// Reports unsaved edits, so the list can confirm before switching rows.
    var isDirty: Binding<Bool> = .constant(false)
    /// The editor closed (saved or cancelled).
    var onEditingEnded: () -> Void = {}
    /// The transaction is gone (deleted): leave the detail.
    var onClose: () -> Void

    var body: some View {
        if let txn = model.transactions.first(where: { $0.id == id }) ?? drafts.transaction(withId: id) {
            TransactionDetailView(
                presentation: model.presentation(for: txn),
                // The editor was open (a draft exists until it closes), so a
                // fold or a rotation reopens it, with or without edits.
                startsEditing: startsEditing || drafts.transaction(withId: id) != nil,
                draft: {
                    drafts.model(for: txn, currency: appState.defaultCurrency, decimalPlaces: appState.decimalPlaces)
                },
                isDirty: isDirty,
                onSaved: { await model.load() },
                onEditingEnded: {
                    drafts.discard()
                    onEditingEnded()
                },
                onSetStatus: { await model.setStatus(txn, to: $0) },
                onDelete: {
                    await model.deleteTransaction(txn)
                    // A failed delete keeps the row (and its error); stay put.
                    guard !model.transactions.contains(where: { $0.id == id }) else { return }
                    if drafts.transaction(withId: id) != nil { drafts.discard() }
                    onClose()
                }
            )
        } else if model.isLoading || model.isReloading {
            ProgressView()
        }
    }
}

extension TransactionListViewModel {
    /// How a transaction reads in its detail, from this list's lookups.
    func presentation(for txn: Transaction) -> TransactionPresentation {
        TransactionPresentation(
            transaction: txn,
            account: account(for: txn),
            category: category(for: txn),
            transferAccountName: transferAccount(for: txn)?.name,
            tags: tags(for: txn),
            budgetName: budgetName(for: txn),
            fixedExpenseName: fixedExpenseName(for: txn),
            isSpread: isSpread(txn)
        )
    }
}
