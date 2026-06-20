import Foundation
import Observation

@Observable
@MainActor
final class AccountDetailViewModel {
    var account: Account?
    var currentBalance: Int64 = 0
    var isLoading = false
    var errorMessage: String?

    private let accountRepo = AccountRepository()

    let accountId: UUID

    init(accountId: UUID) {
        self.accountId = accountId
    }

    // The account's own transaction list is wired up with the Transactions
    // feature (P04); the detail screen here shows account info + edit/archive.
    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let accountResult = accountRepo.getById(accountId)
            async let balanceResult = accountRepo.getCurrentBalance(accountId: accountId)

            account = try await accountResult
            currentBalance = try await balanceResult
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
