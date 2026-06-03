import Foundation
import Observation

@Observable
@MainActor
final class ScheduledTransactionViewModel {
    var scheduledTransactions: [ScheduledTransaction] = []
    var pendingTransactions: [Transaction] = []
    var isLoading = false
    var errorMessage: String?

    private let repository = ScheduledTransactionRepository()

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let scheduled = repository.getAll()
            async let pending = repository.getPendingTransactions()

            scheduledTransactions = try await scheduled
            pendingTransactions = try await pending
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmPending(_ pending: Transaction) async {
        do {
            try await repository.confirmPending(id: pending.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissPending(_ pending: Transaction) async {
        do {
            try await repository.dismissPending(id: pending.id)
            pendingTransactions.removeAll { $0.id == pending.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
