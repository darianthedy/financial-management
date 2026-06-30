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
    private let supabase = SupabaseService.shared.client
    private var realtimeChannel: RealtimeChannelV2?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            categories = try await repository.list()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func subscribeToChanges() async {
        let channel = supabase.realtimeV2.channel("categories-realtime")
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "categories")
        await channel.subscribe()
        Task {
            for await _ in changes {
                await load()
            }
        }
        realtimeChannel = channel
    }

    func unsubscribe() async {
        if let channel = realtimeChannel {
            await supabase.realtimeV2.removeChannel(channel)
            realtimeChannel = nil
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
