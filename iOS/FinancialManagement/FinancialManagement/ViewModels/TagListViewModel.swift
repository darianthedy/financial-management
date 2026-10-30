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
    private let realtime = RealtimeTableWatch()
    private var currentUserId: UUID? {
        get async { try? await supabase.auth.session.user.id }
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

    /// Keeps the list live until the calling task is cancelled.
    func subscribeToChanges() async {
        guard let userId = await currentUserId else { return }
        await realtime.watch(topic: "tags-realtime-\(userId)", tables: ["tags"]) { [weak self] in
            await self?.load()
        }
    }

    func create(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let userId = await currentUserId else { return }
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
