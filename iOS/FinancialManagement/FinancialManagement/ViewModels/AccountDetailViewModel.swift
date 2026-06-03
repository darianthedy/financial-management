import Foundation
import Observation

@Observable
@MainActor
final class AccountDetailViewModel {
    var account: Account?
    var currentBalance: Int64 = 0
    var transactions: [Transaction] = []
    var isLoading = false
    var errorMessage: String?

    private let accountRepo = AccountRepository()
    private let transactionRepo = TransactionRepository()

    let accountId: UUID

    init(accountId: UUID) {
        self.accountId = accountId
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let accountResult = accountRepo.getById(accountId)
            async let balanceResult = accountRepo.getCurrentBalance(accountId: accountId)
            async let txnResult = transactionRepo.getAll(accountId: accountId)

            account = try await accountResult
            currentBalance = try await balanceResult
            transactions = try await txnResult
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func archiveAccount() async {
        do {
            try await accountRepo.archive(id: accountId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
