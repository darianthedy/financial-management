import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class TagListViewModel {
    var tags: [Tag] = []
    var isLoading = false
    var errorMessage: String?

    private let repository = TagRepository()
    private let supabase = SupabaseService.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var currentUserId: UUID? {
        try? supabase.auth.session.user.id
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            tags = try await repository.list()
        } catch {
            errorMessage = error.localizedDescription
            tags = []
        }
    }

    func subscribeToChanges() async {
        guard let userId = currentUserId else { return }
        let channel = supabase.realtimeV2.channel("tags-realtime-\(userId)")
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "tags")
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

    func create(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let userId = currentUserId else { return }
        do {
            let tag = try await repository.create(name: trimmed, userId: userId)
            tags.append(tag)
            tags.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(id: UUID, name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            let updated = try await repository.update(id: id, name: trimmed)
            if let index = tags.firstIndex(where: { $0.id == id }) {
                tags[index] = updated
                tags.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ tag: Tag) async {
        do {
            try await repository.delete(id: tag.id)
            tags.removeAll { $0.id == tag.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
