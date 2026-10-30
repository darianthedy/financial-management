import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class CategoryListViewModel {
    var categories: [Category] = []
    var isLoading = false
    var errorMessage: String?

    private let repository = CategoryRepository()
    private let realtime = RealtimeTableWatch()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            categories = try await repository.list()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Keeps the list live until the calling task is cancelled.
    func subscribeToChanges() async {
        await realtime.watch(topic: "categories-realtime", tables: ["categories"]) { [weak self] in
            await self?.load()
        }
    }

    func delete(_ category: Category) async {
        do {
            try await repository.delete(id: category.id)
            categories.removeAll { $0.id == category.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
