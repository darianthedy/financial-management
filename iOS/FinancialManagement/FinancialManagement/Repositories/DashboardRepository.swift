import Foundation
import Supabase

struct DashboardSummary {
    var totalIncome: Int64
    var totalExpense: Int64
    var netCashflow: Int64
    var spendingByCategory: [CategorySpending]
    var recentTransactions: [Transaction]
}

struct CategorySpending: Codable, Sendable {
    let categoryId: UUID
    let categoryName: String
    let icon: String?
    let color: String?
    let totalAmount: Int64

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case categoryName = "category_name"
        case icon, color
        case totalAmount = "total_amount"
    }
}

actor DashboardRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    func getSummary(yearMonth: String) async throws -> DashboardSummary {
        let startDate = "\(yearMonth)-01"
        let endYearMonth = DateUtils.navigate(yearMonth, by: 1)
        let endDate = "\(endYearMonth)-01"

        let transactions: [Transaction] = try await client
            .from("transactions")
            .select()
            .gte("date", value: startDate)
            .lt("date", value: endDate)
            .order("date", ascending: false)
            .execute()
            .value

        let totalIncome = transactions
            .filter { $0.type == .income }
            .reduce(Int64(0)) { $0 + $1.amount }

        let totalExpense = transactions
            .filter { $0.type == .expense }
            .reduce(Int64(0)) { $0 + $1.amount }

        let spendingByCategory: [CategorySpending] = try await client
            .from("v_spending_by_category")
            .select()
            .eq("year_month", value: yearMonth)
            .order("total_amount", ascending: false)
            .execute()
            .value

        let recentTransactions = Array(transactions.prefix(5))

        return DashboardSummary(
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            netCashflow: totalIncome - totalExpense,
            spendingByCategory: spendingByCategory,
            recentTransactions: recentTransactions
        )
    }
}
