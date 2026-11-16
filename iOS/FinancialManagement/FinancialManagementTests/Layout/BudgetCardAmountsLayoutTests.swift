import SwiftUI
import XCTest
@testable import FinancialManagement

/// Design review 02: the "spent of budget" label must never wrap mid-phrase.
/// The amounts row keeps one row when it fits and otherwise stacks into whole
/// lines, each figure on a single line.
@MainActor
final class BudgetCardAmountsLayoutTests: XCTestCase {
    private let currency = "IDR"

    /// Whole rupiah → the stored minor units for `currency`.
    private func amount(_ rupiah: Int64) -> Int64 {
        var value = rupiah
        for _ in 0..<CurrencyUtils.fractionDigits(for: currency) { value *= 10 }
        return value
    }

    private func progress(_ name: String, spent: Int64, budget: Int64) -> BudgetProgress {
        BudgetProgress(
            budgetId: UUID(), userId: UUID(), budgetName: name, yearMonth: "2026-11",
            periodicAmount: amount(budget), carryOverAmount: 0, effectiveAmount: amount(budget),
            spent: amount(spent), remaining: amount(budget - spent), reserved: 0, description: nil
        )
    }

    /// The review's two long rows plus one that clearly fits. Tests run pinned
    /// to en/US ("IDR 310,500", wider than the app's "Rp 310.500"), so the
    /// short row uses smaller figures to stay well inside one line.
    private var cards: [BudgetProgress] {
        [
            progress("Dining Out", spent: 1_682_000, budget: 1_500_000),
            progress("Groceries", spent: 2_145_300, budget: 3_000_000),
            progress("Transport", spent: 31_000, budget: 80_000),
        ]
    }

    private func render(at size: LayoutSize, type: DynamicTypeSize = .large) async throws -> LayoutSnapshot {
        let cards = cards
        let currency = currency
        let probes = cards.map { "budgets.amounts.remaining.\($0.budgetName)" }
        return try await LayoutHarness.render(
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(cards) { BudgetCard(progress: $0, currencyCode: currency) }
                }
                .padding(.horizontal, 16)
            }
            .environment(\.dynamicTypeSize, type),
            at: size,
            until: { records in probes.allSatisfy { records[$0] != nil } }
        )
    }

    private func frames(_ snapshot: LayoutSnapshot, _ name: String) throws -> (spent: CGRect, remaining: CGRect) {
        (try snapshot.frame("budgets.amounts.spent.\(name)"),
         try snapshot.frame("budgets.amounts.remaining.\(name)"))
    }

    /// No label wraps: the spent label is one line tall (the remaining label is
    /// always one line), and the two never overlap.
    private func assertWholeLines(_ snapshot: LayoutSnapshot, _ context: String) throws {
        for card in cards {
            let (spent, remaining) = try frames(snapshot, card.budgetName)
            XCTAssertLessThan(spent.height, remaining.height * 1.5,
                              "\(card.budgetName) spent label wraps (\(context))")
            XCTAssertFalse(spent.intersects(remaining), "\(card.budgetName) labels overlap (\(context))")
        }
    }

    func testOuterDisplayStacksLongAmountsAndKeepsShortOnesOnOneRow() async throws {
        let snapshot = try await render(at: .outerPortrait)
        attach(snapshot, name: "budget-amounts")
        try assertWholeLines(snapshot, "outer")

        for name in ["Dining Out", "Groceries"] {
            let (spent, remaining) = try frames(snapshot, name)
            XCTAssertGreaterThanOrEqual(remaining.minY, spent.maxY - 1, "\(name) should stack")
            XCTAssertEqual(remaining.minX, spent.minX, accuracy: 1, "\(name) stack is leading-aligned")
        }
        let (spent, remaining) = try frames(snapshot, "Transport")
        XCTAssertEqual(spent.midY, remaining.midY, accuracy: 1, "Transport fits on one row")
    }

    func testWideLayoutsKeepOneRow() async throws {
        for size in [LayoutSize.innerLandscape, .innerPortrait] {
            let snapshot = try await render(at: size)
            attach(snapshot, name: "budget-amounts")
            try assertWholeLines(snapshot, size.name)
            for card in cards {
                let (spent, remaining) = try frames(snapshot, card.budgetName)
                XCTAssertEqual(spent.midY, remaining.midY, accuracy: 1, "\(card.budgetName) at \(size)")
            }
        }
    }

    func testLargeDynamicTypeNeverWrapsMidPhrase() async throws {
        for type in [DynamicTypeSize.xxxLarge, .accessibility3] {
            let snapshot = try await render(at: .outerPortrait, type: type)
            attach(snapshot, name: "budget-amounts-\(type)")
            try assertWholeLines(snapshot, "\(type)")
        }
    }
}
