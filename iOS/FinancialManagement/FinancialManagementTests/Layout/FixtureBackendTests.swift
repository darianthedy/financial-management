import XCTest
@testable import FinancialManagement

/// The fixture backend's PostgREST filter subset (D0.3). Pure; no fixtures flag needed.
final class FixtureBackendTests: XCTestCase {
    private let rows: [[String: Any]] = [
        ["id": "a", "date": "2026-10-03", "amount": 500, "budget_id": NSNull(), "is_archived": false],
        ["id": "b", "date": "2026-10-20", "amount": 1_500, "budget_id": "B1", "is_archived": true],
        ["id": "c", "date": "2026-11-01", "amount": 90, "budget_id": NSNull(), "is_archived": false],
    ]

    private func ids(_ query: String) -> [String] {
        var items = URLComponents(string: "https://x.invalid/rest/v1/t?\(query)")!.queryItems ?? []
        items.removeAll { $0.name == "order" || $0.name == "limit" }
        var matched = rows.filter { row in items.allSatisfy { PostgRESTFilter.matches(row, $0) } }
        let all = URLComponents(string: "https://x.invalid/rest/v1/t?\(query)")!.queryItems ?? []
        PostgRESTFilter.order(&matched, all)
        PostgRESTFilter.limit(&matched, all)
        return matched.map { $0["id"] as! String }
    }

    func testEqualityIsCaseInsensitive() {
        XCTAssertEqual(ids("budget_id=eq.b1"), ["b"])
        XCTAssertEqual(ids("is_archived=eq.false"), ["a", "c"])
    }

    func testIsNull() {
        XCTAssertEqual(ids("budget_id=is.null"), ["a", "c"])
    }

    func testDateRange() {
        XCTAssertEqual(ids("date=gte.2026-10-01&date=lt.2026-11-01"), ["a", "b"])
    }

    func testNumericComparison() {
        XCTAssertEqual(ids("amount=gt.100"), ["a", "b"])
    }

    func testInList() {
        XCTAssertEqual(ids("id=in.(%22a%22,%22c%22)"), ["a", "c"])
    }

    func testOrderAndLimit() {
        XCTAssertEqual(ids("order=amount.desc&limit=2"), ["b", "a"])
    }

    func testRPCIsARead() {
        var request = URLRequest(url: URL(string: "https://x.invalid/rest/v1/rpc/fn_account_balances_at")!)
        request.httpMethod = "POST"
        request.httpBody = Data(#"{"p_year_month":"2026-10"}"#.utf8)
        let (status, body) = FixtureURLProtocol.respond(to: request)
        XCTAssertEqual(status, 200)
        let decoded = try? JSONSerialization.jsonObject(with: body) as? [[String: Any]]
        XCTAssertEqual(decoded?.count, 4)
    }
}
