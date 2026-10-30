import SwiftUI
import XCTest
@testable import FinancialManagement

/// D5.2: Settings' segmented control stays readable on the inner display.
@MainActor
final class SettingsWidthLayoutTests: XCTestCase {
    override func setUp() async throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "Layout tests need DUO_FIXTURES=1.")
    }

    func testThemePickerIsAtMost560Wide() async throws {
        for size in [LayoutSize.innerLandscape, .innerPortrait] {
            let snapshot = try await LayoutHarness.render(
                NavigationStack { SettingsView() }
                    .environment(AppState())
                    .environment(ThemeManager()),
                at: size,
                until: { $0["settings.theme"] != nil }
            )
            attach(snapshot, name: "settings-width")
            let picker = try snapshot.frame("settings.theme")
            XCTAssertLessThanOrEqual(picker.width, 560, "\(size)")
            // On the Duo simulator a regular-width render inherits the outer
            // display's rail, which shifts the centre (`LayoutHarness.sceneFits`).
            if try LayoutHarness.sceneFits(size) {
                XCTAssertEqual(picker.midX, size.size.width / 2, accuracy: 1, "not centered at \(size)")
            }
        }
    }

    func testCompactKeepsItsFullWidthPicker() async throws {
        let snapshot = try await LayoutHarness.render(
            NavigationStack { SettingsView() }
                .environment(AppState())
                .environment(ThemeManager()),
            at: .outerPortrait,
            until: { $0["settings.theme"] != nil }
        )
        // The grouped list's own insets are all that narrow it.
        XCTAssertGreaterThan(try snapshot.frame("settings.theme").width, 300)
    }
}
