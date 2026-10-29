import SwiftUI
import XCTest
@testable import FinancialManagement

/// The adaptive kill switch (D0.2): parsing, per-configuration value, and the
/// size class it lets through.
final class AdaptiveLayoutTests: XCTestCase {
    func testParsesInfoPlistValues() {
        XCTAssertTrue(AdaptiveLayout.isEnabled(infoValue: "YES"))
        XCTAssertTrue(AdaptiveLayout.isEnabled(infoValue: "true"))
        XCTAssertTrue(AdaptiveLayout.isEnabled(infoValue: "1"))
        XCTAssertTrue(AdaptiveLayout.isEnabled(infoValue: true))
        XCTAssertFalse(AdaptiveLayout.isEnabled(infoValue: "NO"))
        XCTAssertFalse(AdaptiveLayout.isEnabled(infoValue: false))
    }

    /// A build that forgot the setting must fail safe to compact.
    func testMissingOrUnexpandedValueIsOff() {
        XCTAssertFalse(AdaptiveLayout.isEnabled(infoValue: nil))
        XCTAssertFalse(AdaptiveLayout.isEnabled(infoValue: ""))
        XCTAssertFalse(AdaptiveLayout.isEnabled(infoValue: "$(ADAPTIVE_LAYOUT_ENABLED)"))
    }

    /// Tests run against the Debug build, where the switch is on. Release
    /// keeps it off until D7.1 (project.pbxproj: ADAPTIVE_LAYOUT_ENABLED).
    func testDebugBuildHasSwitchOn() {
        #if DEBUG
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: AdaptiveLayout.infoKey) as? String, "YES")
        XCTAssertTrue(AdaptiveLayout.isEnabled)
        #endif
    }

    func testOffPinsCompact() {
        XCTAssertEqual(AdaptiveLayout.effectiveSizeClass(.regular, enabled: false), .compact)
        XCTAssertEqual(AdaptiveLayout.effectiveSizeClass(.compact, enabled: false), .compact)
        XCTAssertEqual(AdaptiveLayout.effectiveSizeClass(nil, enabled: false), .compact)
    }

    func testOnPassesSystemThrough() {
        XCTAssertEqual(AdaptiveLayout.effectiveSizeClass(.regular, enabled: true), .regular)
        XCTAssertEqual(AdaptiveLayout.effectiveSizeClass(.compact, enabled: true), .compact)
    }
}
