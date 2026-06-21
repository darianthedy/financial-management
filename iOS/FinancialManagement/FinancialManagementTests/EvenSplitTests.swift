import XCTest
@testable import FinancialManagement

/// Unit tests for the even-split grid math behind virtual installments (§13,
/// §8.8). The invariant the UI depends on: the cells always sum back to the
/// expense total, with the rounding remainder parked in the first cell.
final class EvenSplitTests: XCTestCase {
    func testEvenDivisionSplitsEqually() {
        XCTAssertEqual(EvenSplit.distribute(total: 900, count: 3), [300, 300, 300])
    }

    func testRemainderGoesToFirstCell() {
        // 1000 / 3 = 333 each, remainder 1 → first cell carries it.
        XCTAssertEqual(EvenSplit.distribute(total: 1000, count: 3), [334, 333, 333])
    }

    func testAlwaysSumsToTotal() {
        for total in Int64(0)...200 {
            for count in 1...12 {
                let cells = EvenSplit.distribute(total: total, count: count)
                XCTAssertEqual(cells.count, count)
                XCTAssertEqual(cells.reduce(0, +), total, "total=\(total) count=\(count)")
            }
        }
    }

    func testSingleCellGetsEverything() {
        XCTAssertEqual(EvenSplit.distribute(total: 12345, count: 1), [12345])
    }

    func testZeroCountYieldsEmpty() {
        XCTAssertEqual(EvenSplit.distribute(total: 1000, count: 0), [])
        XCTAssertEqual(EvenSplit.distribute(total: 1000, count: -3), [])
    }

    func testZeroTotalYieldsAllZeros() {
        XCTAssertEqual(EvenSplit.distribute(total: 0, count: 4), [0, 0, 0, 0])
    }
}
