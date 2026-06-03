import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    var currencies: [Currency] = []
    var defaultCurrency: String = "USD"
    var isLoading = false
    var errorMessage: String?
    var searchText = ""

    private let repository = CurrencyRepository()

    var filteredCurrencies: [Currency] {
        if searchText.isEmpty { return currencies }
        let query = searchText.lowercased()
        return currencies.filter {
            $0.code.lowercased().contains(query) ||
            $0.name.lowercased().contains(query)
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            currencies = try await repository.getAllCurrencies()
            if let settings = try await repository.getUserSettings() {
                defaultCurrency = settings.defaultCurrency
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateDefaultCurrency(_ code: String) async {
        do {
            let settings = try await repository.upsertDefaultCurrency(code)
            defaultCurrency = settings.defaultCurrency
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func currency(for code: String) -> Currency? {
        currencies.first { $0.code == code }
    }
}
