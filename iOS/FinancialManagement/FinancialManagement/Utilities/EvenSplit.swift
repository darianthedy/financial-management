import Foundation

/// Pure even-split allocation used by the virtual-installment grid (§8.8). Splits
/// `total` minor units across `count` cells as `floor(total / count)` each, with
/// the rounding remainder dropped into the **first** cell so the result sums back
/// to `total` exactly (the RPC re-validates that invariant on save).
enum EvenSplit {
    static func distribute(total: Int64, count: Int) -> [Int64] {
        guard count > 0 else { return [] }
        let n = Int64(count)
        let per = total / n
        let remainder = total - per * n
        return (0..<count).map { index in
            per + (index == 0 ? remainder : 0)
        }
    }
}
