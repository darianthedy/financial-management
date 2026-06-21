import XCTest
import Supabase
@testable import FinancialManagement

/// Repository-layer test (§13): `BudgetRepository.progress` must read from the
/// `v_budget_progress` view and decode its rows into `BudgetProgress`. A mocked
/// `URLSession` stands in for Supabase so the test asserts both the endpoint and
/// the decoding without any network.
final class BudgetRepositoryTests: XCTestCase {
    private func makeClient(session: URLSession) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseKey: "test-anon-key",
            options: .init(global: .init(session: session))
        )
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testProgressReadsFromBudgetProgressView() async throws {
        let rowJSON = """
        [{
          "budget_id": "44444444-4444-4444-4444-444444444444",
          "user_id": "22222222-2222-2222-2222-222222222222",
          "budget_name": "Food",
          "year_month": "2026-06",
          "periodic_amount": 50000,
          "carry_over_amount": 0,
          "effective_amount": 50000,
          "spent": 12000,
          "remaining": 38000,
          "reserved": 0,
          "description": null
        }]
        """.data(using: .utf8)!

        var requestedURL: URL?
        MockURLProtocol.handler = { request in
            requestedURL = request.url
            return (200, rowJSON)
        }

        let repo = BudgetRepository(client: makeClient(session: MockURLProtocol.makeSession()))
        let rows = try await repo.progress(yearMonth: "2026-06")

        // Endpoint: the view, filtered by month.
        let urlString = requestedURL?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("v_budget_progress"), "hit \(urlString)")
        XCTAssertTrue(urlString.contains("year_month"), "should filter by month: \(urlString)")

        // Decoding into the read model.
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.budgetName, "Food")
        XCTAssertEqual(rows.first?.spent, 12_000)
        XCTAssertEqual(rows.first?.effectiveAmount, 50_000)
    }

    func testProgressDecodesEmptyResult() async throws {
        MockURLProtocol.handler = { _ in (200, Data("[]".utf8)) }
        let repo = BudgetRepository(client: makeClient(session: MockURLProtocol.makeSession()))
        let rows = try await repo.progress(yearMonth: "2026-06")
        XCTAssertTrue(rows.isEmpty)
    }
}
