import XCTest
@testable import FinancialManagement

/// D3.1: the Transactions detail form's draft lives outside every size-class
/// branch, so unsaved edits survive the fold / unfold that re-creates the form.
@MainActor
final class TransactionEditorDraftsTests: XCTestCase {
    private func transaction(_ n: Int, amount: Int64 = 12_500) -> Transaction {
        let id = UUID(uuidString: String(format: "00000000-0000-4000-8000-%012x", n))!
        return Transaction(
            id: id, userId: UUID(), accountId: UUID(), type: .expense, status: .confirmed,
            amount: amount, description: "Coffee", transactionDate: Date(),
            transferAccountId: nil, budgetId: nil, categoryId: nil, scheduledTxnId: nil,
            fixedExpenseId: nil, tagIds: nil, createdAt: Date(), updatedAt: Date()
        )
    }

    func testUnsavedEditsSurviveASizeClassChange() {
        let drafts = TransactionEditorDrafts()
        let txn = transaction(1)

        // Regular width: the tiled detail column starts the draft; the user edits.
        let tiled = drafts.model(for: txn, currency: "IDR", decimalPlaces: 0)
        tiled.description = "Coffee beans"
        tiled.amount = "99"
        XCTAssertTrue(tiled.hasChanges)

        // Fold: the list and form are re-created and ask again (the compact push).
        let pushed = drafts.model(for: txn, currency: "IDR", decimalPlaces: 0)
        XCTAssertTrue(pushed === tiled)
        XCTAssertEqual(pushed.description, "Coffee beans")
        XCTAssertEqual(pushed.amount, "99")
        XCTAssertTrue(pushed.hasChanges)
    }

    func testAnotherTransactionStartsAFreshDraft() {
        let drafts = TransactionEditorDrafts()
        let first = drafts.model(for: transaction(1), currency: "IDR", decimalPlaces: 0)
        first.description = "Edited"

        let second = drafts.model(for: transaction(2), currency: "IDR", decimalPlaces: 0)
        XCTAssertFalse(second === first)
        XCTAssertFalse(second.hasChanges)
        XCTAssertEqual(drafts.transaction?.id, transaction(2).id)
    }

    func testDiscardDropsTheDraft() {
        let drafts = TransactionEditorDrafts()
        let txn = transaction(1)
        let model = drafts.model(for: txn, currency: "IDR", decimalPlaces: 0)
        model.description = "Edited"
        XCTAssertNotNil(drafts.transaction(withId: txn.id))

        drafts.discard()
        XCTAssertNil(drafts.transaction)
        XCTAssertNil(drafts.transaction(withId: txn.id))
        XCTAssertFalse(drafts.model(for: txn, currency: "IDR", decimalPlaces: 0).hasChanges)
    }

    func testDraftTransactionIsOnlyFoundById() {
        let drafts = TransactionEditorDrafts()
        _ = drafts.model(for: transaction(1), currency: "IDR", decimalPlaces: 0)
        XCTAssertNotNil(drafts.transaction(withId: transaction(1).id))
        XCTAssertNil(drafts.transaction(withId: transaction(2).id))
    }
}
