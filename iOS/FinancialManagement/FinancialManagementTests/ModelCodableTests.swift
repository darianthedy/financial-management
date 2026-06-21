import XCTest
@testable import FinancialManagement

/// Codable round-trip tests for the models that cross the Supabase boundary
/// (§13). They assert the snake_case `CodingKeys` mapping and the date decoding
/// the app relies on, by decoding a server-shaped payload, re-encoding it, and
/// decoding again.
final class ModelCodableTests: XCTestCase {
    // Mirrors SupabaseService's PostgREST coders so tests exercise the same
    // date handling the live client uses.
    private let decoder = TestCoders.decoder
    private let encoder = TestCoders.encoder

    func testAccountRoundTrip() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "user_id": "22222222-2222-2222-2222-222222222222",
          "name": "Checking",
          "type": "bank_account",
          "starting_balance": 150000,
          "image_url": null,
          "is_archived": false,
          "show_on_dashboard": true,
          "created_at": "2026-06-01T08:30:00Z",
          "updated_at": "2026-06-02T09:00:00.123Z"
        }
        """.data(using: .utf8)!

        let account = try decoder.decode(Account.self, from: json)
        XCTAssertEqual(account.name, "Checking")
        XCTAssertEqual(account.type, .bankAccount)
        XCTAssertEqual(account.startingBalance, 150_000)
        XCTAssertNil(account.imageUrl)
        XCTAssertFalse(account.isArchived)
        XCTAssertTrue(account.showOnDashboard)

        let reDecoded = try decoder.decode(Account.self, from: try encoder.encode(account))
        XCTAssertEqual(reDecoded.id, account.id)
        XCTAssertEqual(reDecoded.startingBalance, account.startingBalance)
        XCTAssertEqual(reDecoded.type, account.type)
        XCTAssertEqual(reDecoded.showOnDashboard, account.showOnDashboard)
    }

    func testTransactionRoundTripWithDateOnlyField() throws {
        let json = """
        {
          "id": "33333333-3333-3333-3333-333333333333",
          "user_id": "22222222-2222-2222-2222-222222222222",
          "account_id": "11111111-1111-1111-1111-111111111111",
          "type": "expense",
          "status": "confirmed",
          "amount": 4250,
          "description": "Groceries",
          "date": "2026-06-15",
          "transfer_account_id": null,
          "budget_id": null,
          "category_id": null,
          "scheduled_txn_id": null,
          "fixed_expense_id": null,
          "created_at": "2026-06-15T10:00:00Z",
          "updated_at": "2026-06-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let txn = try decoder.decode(Transaction.self, from: json)
        XCTAssertEqual(txn.type, .expense)
        XCTAssertEqual(txn.status, .confirmed)
        XCTAssertEqual(txn.amount, 4250)
        XCTAssertEqual(txn.description, "Groceries")
        XCTAssertEqual(DateUtils.yearMonthDay(from: txn.transactionDate), "2026-06-15")

        let reDecoded = try decoder.decode(Transaction.self, from: try encoder.encode(txn))
        XCTAssertEqual(reDecoded.amount, txn.amount)
        XCTAssertEqual(reDecoded.type, txn.type)
        XCTAssertEqual(reDecoded.description, txn.description)
    }

    func testBudgetProgressDecodesViewColumns() throws {
        let json = """
        {
          "budget_id": "44444444-4444-4444-4444-444444444444",
          "user_id": "22222222-2222-2222-2222-222222222222",
          "budget_name": "Food",
          "year_month": "2026-06",
          "periodic_amount": 50000,
          "carry_over_amount": 1000,
          "effective_amount": 51000,
          "spent": 20000,
          "remaining": 26000,
          "reserved": 5000,
          "description": "Eating out + groceries"
        }
        """.data(using: .utf8)!

        let progress = try decoder.decode(BudgetProgress.self, from: json)
        XCTAssertEqual(progress.budgetName, "Food")
        XCTAssertEqual(progress.effectiveAmount, 51_000)
        XCTAssertEqual(progress.effectiveAmount, progress.periodicAmount + progress.carryOverAmount)
        XCTAssertEqual(progress.remaining, progress.effectiveAmount - progress.spent - progress.reserved)
        XCTAssertEqual(progress.id, progress.budgetId)
    }

    func testVTransactionRowDecodesTagArray() throws {
        let json = """
        {
          "id": "55555555-5555-5555-5555-555555555555",
          "type": "income",
          "status": "pending",
          "amount": 9000,
          "account_id": "11111111-1111-1111-1111-111111111111",
          "transfer_account_id": null,
          "category_id": null,
          "budget_id": null,
          "fixed_expense_id": null,
          "tag_ids": ["66666666-6666-6666-6666-666666666666"]
        }
        """.data(using: .utf8)!

        let row = try decoder.decode(VTransactionRow.self, from: json)
        XCTAssertEqual(row.type, .income)
        XCTAssertEqual(row.status, .pending)
        XCTAssertEqual(row.tagIds.count, 1)
    }

    func testEmptyTagArrayDecodes() throws {
        let json = """
        {
          "id": "55555555-5555-5555-5555-555555555555",
          "type": "transfer", "status": "confirmed", "amount": 100,
          "account_id": "11111111-1111-1111-1111-111111111111",
          "transfer_account_id": "11111111-1111-1111-1111-111111111112",
          "category_id": null, "budget_id": null, "fixed_expense_id": null,
          "tag_ids": []
        }
        """.data(using: .utf8)!

        let row = try decoder.decode(VTransactionRow.self, from: json)
        XCTAssertTrue(row.tagIds.isEmpty)
        XCTAssertEqual(row.type, .transfer)
    }
}
