import Foundation
import Supabase

/// Watches database tables over realtime for as long as the calling task runs.
///
/// The SDK caches channels by topic, and listeners can't be added to a channel
/// that is joining. So a screen re-created while its channel is still joining
/// (a fold, or a quick tab switch) would get the old channel, lose its
/// listeners, and silently stop updating. Each watch therefore removes a
/// leftover channel first and starts a fresh one, and only ever removes the
/// channel it created. Setup and teardown run one at a time, in call order.
@MainActor
final class RealtimeTableWatch {
    private static var queue: Task<Void, Never>?

    /// Returns when the calling task is cancelled. Call it from a view's
    /// `.task`, so the watch ends when the view disappears.
    func watch(
        topic: String,
        tables: [String],
        onChange: @escaping @MainActor () async -> Void
    ) async {
        let (channel, tasks) = await Self.inOrder {
            await Self.start(topic: topic, tables: tables, onChange: onChange)
        }

        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3600))
        }

        tasks.forEach { $0.cancel() }
        await Self.inOrder {
            // A newer watch may already own this topic.
            if supabase.realtimeV2.channels[channel.topic] === channel {
                await supabase.realtimeV2.removeChannel(channel)
            }
        }
    }

    private static func start(
        topic: String,
        tables: [String],
        onChange: @escaping @MainActor () async -> Void
    ) async -> (RealtimeChannelV2, [Task<Void, Never>]) {
        if let leftover = supabase.realtimeV2.channels["realtime:\(topic)"] {
            await supabase.realtimeV2.removeChannel(leftover)
        }

        let channel = supabase.realtimeV2.channel(topic)
        var tasks = tables.map { table in
            let changes = channel.postgresChange(AnyAction.self, schema: "public", table: table)
            return Task { @MainActor in
                for await _ in changes { await onChange() }
            }
        }
        // Not awaited: joining can take a while, or never finish offline, and
        // must not hold up the queue.
        tasks.append(Task { await channel.subscribe() })
        return (channel, tasks)
    }

    /// Runs `operation` after every operation queued before it.
    private static func inOrder<T>(_ operation: @escaping @MainActor () async -> T) async -> T {
        let previous = queue
        let task = Task { @MainActor in
            await previous?.value
            return await operation()
        }
        queue = Task { _ = await task.value }
        return await task.value
    }
}
