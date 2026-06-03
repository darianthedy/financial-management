import Foundation
import Supabase

@MainActor
final class RealtimeService {
    static let shared = RealtimeService()

    private let supabase = SupabaseService.shared.client
    private var channels: [String: RealtimeChannelV2] = [:]

    private init() {}

    func subscribe(
        to table: String,
        schema: String = "public",
        onChange: @escaping @Sendable () async -> Void
    ) async -> String {
        let channelId = "\(table)-realtime-\(UUID().uuidString.prefix(8))"
        let channel = supabase.realtimeV2.channel(channelId)

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: schema,
            table: table
        )

        await channel.subscribe()

        Task {
            for await _ in changes {
                await onChange()
            }
        }

        channels[channelId] = channel
        return channelId
    }

    func unsubscribe(channelId: String) async {
        guard let channel = channels.removeValue(forKey: channelId) else { return }
        await supabase.realtimeV2.removeChannel(channel)
    }

    func unsubscribeAll() async {
        for (_, channel) in channels {
            await supabase.realtimeV2.removeChannel(channel)
        }
        channels.removeAll()
    }
}
