import Supabase
import XCTest
@testable import FinancialManagement

/// A re-created screen must get its own channel, even while the old one is
/// still joining, and the old screen leaving must not remove the new channel.
@MainActor
final class RealtimeTableWatchTests: XCTestCase {
    private let topic = "realtime-table-watch-test"
    private var realtime: RealtimeClientV2 { SupabaseService.shared.client.realtimeV2 }
    private var key: String { "realtime:\(topic)" }

    private func start() -> Task<Void, Never> {
        let topic = topic
        return Task { await RealtimeTableWatch().watch(topic: topic, tables: ["accounts"]) {} }
    }

    private func poll(until done: () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while !done(), clock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    func testNewWatchReplacesAJoiningChannel() async throws {
        let first = start()
        try await poll { realtime.channels[key] != nil }
        let firstChannel = try XCTUnwrap(realtime.channels[key])

        let second = start()
        try await poll { realtime.channels[key] !== firstChannel }
        let secondChannel = try XCTUnwrap(realtime.channels[key])
        XCTAssertFalse(secondChannel === firstChannel)

        // The old screen leaves after the new one arrived, as in a fold.
        first.cancel()
        await first.value
        XCTAssertTrue(realtime.channels[key] === secondChannel)

        second.cancel()
        await second.value
        XCTAssertNil(realtime.channels[key])
    }
}
