import SwiftUI
import XCTest
@testable import FinancialManagement

/// D2.0: `SplitRootContainer` + `.splitDetail` push on compact width (exactly
/// as `navigationDestination(item:)` did) and tile list | detail on regular
/// width, with a placeholder while nothing is selected.
@MainActor
final class SplitRootLayoutTests: XCTestCase {
    /// A stand-in list screen, shaped like the real ones: it owns its selection
    /// and applies `.splitDetail` after its title and toolbar.
    private struct DummyList: View {
        let storageKey: String
        @State var selection: String?
        let items = ["Alpha", "Bravo", "Charlie"]

        var body: some View {
            List(items, id: \.self) { item in
                Button { selection = item } label: {
                    Text(item).frame(maxWidth: .infinity, alignment: .leading)
                }
                    .splitRowSelected(selection == item)
                    .layoutProbe("row.\(item)", interactive: true)
            }
            .navigationTitle("Dummy")
            .splitDetail(
                selection: $selection, in: items, id: { $0 }, storageKey: storageKey,
                placeholder: SplitPlaceholder(title: "Select an Item", systemImage: "list.bullet")
            ) { item in
                Text("Detail \(item)")
                    .layoutProbe("detail.\(item)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle(item)
            }
        }
    }

    private func render(selected: String?, at size: LayoutSize) async throws -> LayoutSnapshot {
        try await LayoutHarness.render(
            SplitRootContainer {
                DummyList(storageKey: "test.\(UUID().uuidString)", selection: selected)
            },
            at: size,
            timeout: .seconds(3),
            until: { frames in
                selected == nil
                    ? frames["row.Alpha"] != nil
                    : frames["split.detail"] != nil
            }
        )
    }

    func testNothingSelected() async throws {
        for size in LayoutSize.all {
            let snapshot = try await render(selected: nil, at: size)
            attach(snapshot, name: "split-empty")
            let row = try snapshot.frame("row.Alpha")
            XCTAssertNil(snapshot.frames["split.detail"], "\(size)")

            if size.horizontal == .regular {
                let list = try snapshot.frame("split.list")
                let placeholder = try snapshot.frame("split.placeholder")
                XCTAssertLessThanOrEqual(list.maxX, placeholder.minX + 1, "list | placeholder must tile at \(size)")
            } else {
                XCTAssertNil(snapshot.frames["split.list"], "compact must not split at \(size)")
                XCTAssertNil(snapshot.frames["split.placeholder"], "\(size)")
                try assertCompactContentWidth(snapshot, probe: "row.Alpha")
                XCTAssertGreaterThan(row.width, 0)
            }
            assertNoInteractiveOverlap(snapshot)
        }
    }

    func testSelectionShowsDetail() async throws {
        for size in LayoutSize.all {
            let snapshot = try await render(selected: "Bravo", at: size)
            attach(snapshot, name: "split-selected")
            let detail = try snapshot.frame("split.detail")

            if size.horizontal == .regular {
                // Tiled: the list stays on screen beside the detail.
                let list = try snapshot.frame("split.list")
                XCTAssertLessThanOrEqual(list.maxX, detail.minX + 1, "list | detail must tile at \(size)")
                XCTAssertNil(snapshot.frames["split.placeholder"], "\(size)")
            } else {
                // Pushed: the detail takes the whole safe width.
                try assertCompactContentWidth(snapshot, probe: "split.detail")
                XCTAssertNil(snapshot.frames["split.list"], "\(size)")
            }
            XCTAssertNotNil(snapshot.frames["detail.Bravo"], "the selected item's detail is missing at \(size)")
        }
    }
}
