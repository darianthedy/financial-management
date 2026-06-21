import XCTest
import Supabase
@testable import FinancialManagement

/// Tests the filter-state value type and the shared `applyFilters` predicate
/// builder's short-circuit behaviour (§13, §8.3.1, §4.9). The builder paths that
/// resolve names over the network are deliberately not exercised here — only the
/// pure, no-IO branches (empty filters, and the "matches nothing" facets).
final class TransactionFiltersTests: XCTestCase {
    // A client that never issues a request in these tests (no `.execute()` is
    // called); it only seeds the query builder.
    private func makeClient() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseKey: "test-anon-key"
        )
    }

    private func baseQuery(_ client: SupabaseClient) -> PostgrestFilterBuilder {
        client.from("v_transactions").select("*", count: .exact)
    }

    // MARK: - Value type

    func testEmptyFiltersHaveNoActiveFacets() {
        let f = TransactionFilters()
        XCTAssertEqual(f.activeCount, 0)
        XCTAssertTrue(f.isEmpty)
    }

    func testActiveCountCountsEachEngagedFacetOnce() {
        var f = TransactionFilters()
        f.search = "coffee"
        f.types = Facet(values: [.expense])
        f.dateFrom = Date()
        f.dateTo = Date()                 // date counts once even with both bounds
        f.amountMin = 100
        XCTAssertEqual(f.activeCount, 4)
        XCTAssertFalse(f.isEmpty)
    }

    func testBlankSearchDoesNotCount() {
        var f = TransactionFilters()
        f.search = "   "
        XCTAssertEqual(f.activeCount, 0)
    }

    func testFacetMatchesNothingWhenEmptyAndNoBlanks() {
        XCTAssertTrue(Facet<TransactionType>(values: [], includeBlanks: false).matchesNothing)
        XCTAssertFalse(Facet<TransactionType>(values: [.income], includeBlanks: false).matchesNothing)
        XCTAssertFalse(Facet<TransactionType>(values: [], includeBlanks: true).matchesNothing)
    }

    func testFiltersCodableRoundTrip() throws {
        var f = TransactionFilters()
        f.search = "rent"
        f.types = Facet(values: [.expense, .income])
        f.statuses = Facet(values: [.confirmed])
        f.amountMin = 500
        f.amountMax = 9000
        f.categories = Facet(values: [UUID()], includeBlanks: true)

        let data = try JSONEncoder().encode(f)
        let decoded = try JSONDecoder().decode(TransactionFilters.self, from: data)
        XCTAssertEqual(decoded, f)
    }

    // MARK: - applyFilters predicate building

    func testApplyFiltersReturnsBuilderForEmptyFilters() async throws {
        let client = makeClient()
        let result = try await applyFilters(TransactionFilters(), to: baseQuery(client), client: client)
        XCTAssertNotNil(result, "empty filters must produce a runnable query")
    }

    func testApplyFiltersShortCircuitsOnImpossibleTriStateFacet() async throws {
        let client = makeClient()
        var f = TransactionFilters()
        f.types = Facet(values: [], includeBlanks: false)   // engaged but unchecked → nothing
        let result = try await applyFilters(f, to: baseQuery(client), client: client)
        XCTAssertNil(result, "an empty engaged facet must short-circuit to no rows")
    }

    func testApplyFiltersShortCircuitsOnEmptyCategoryFacet() async throws {
        let client = makeClient()
        var f = TransactionFilters()
        f.categories = Facet(values: [], includeBlanks: false)
        let result = try await applyFilters(f, to: baseQuery(client), client: client)
        XCTAssertNil(result)
    }

    func testApplyFiltersKeepsQueryWhenCategoryIncludesBlanks() async throws {
        let client = makeClient()
        var f = TransactionFilters()
        f.categories = Facet(values: [], includeBlanks: true)   // "(Blanks)" only → valid
        let result = try await applyFilters(f, to: baseQuery(client), client: client)
        XCTAssertNotNil(result)
    }
}
