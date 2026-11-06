import XCTest

/// iPhone Duo bar probe (docs/ios-iphone-duo-plan.md §1.3), the XCUITest half
/// of `FinancialManagementTests/DuoProbeTests`. Not a correctness test: it
/// records where the system puts the navigation bars, tab bars and toolbars,
/// and each of their buttons, on the real app's screens (fixture backend) in
/// portrait and landscape — the evidence for which edge a vertical bar takes
/// and which toolbar items overflow into "…". Frames are `XCUIElement.frame`,
/// in screen points.
///
/// Each probe writes `<name>.json` + `<name>.png` to `DUO_OUT` and attaches
/// both to the result bundle, as `DuoProbeTests` does. Skipped unless
/// `DUO_PROBE=1` (CI passes `TEST_RUNNER_DUO_PROBE=1`).
final class DuoProbeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func test1_barsPortrait() throws {
        try probeScreens(.portrait, suffix: "portrait")
    }

    func test2_barsLandscape() throws {
        try probeScreens(.landscapeLeft, suffix: "landscape")
    }

    // MARK: - Probe runner

    private func probeScreens(_ orientation: UIDeviceOrientation, suffix: String) throws {
        try XCTSkipUnless(env("DUO_PROBE") == "1", "Set DUO_PROBE=1 to run the iPhone Duo bar probe.")
        let app = launchFixtureApp()
        rotate(orientation, in: app)

        for name in ["Dashboard", "Accounts", "Transactions", "Budgets", "More"] {
            openTab(name, in: app)
            settle()
            try probe("app-\(name.lowercased())-\(suffix)", app)
        }

        // A pushed (or, tiled, side-by-side) detail.
        openTab("Accounts", in: app)
        hittableButton(containing: "Jenius", in: app).tap()
        _ = app.navigationBars["Jenius"].waitForExistence(timeout: 10)
        settle()
        try probe("app-account-detail-\(suffix)", app)

        // A form sheet with Cancel / Save.
        openTab("Transactions", in: app)
        let add = app.navigationBars["Transactions"].buttons["Add"]
        if add.waitForExistence(timeout: 5) {
            add.tap()
            _ = app.navigationBars["New Transaction"].waitForExistence(timeout: 10)
            settle()
            try probe("app-sheet-\(suffix)", app)
            app.navigationBars["New Transaction"].buttons["Cancel"].tap()
        }
    }

    private func probe(_ name: String, _ app: XCUIApplication) throws {
        let window = app.windows.firstMatch
        let report: [String: Any] = [
            "simulator": [
                "model": env("SIMULATOR_MODEL_IDENTIFIER"),
                "deviceName": env("SIMULATOR_DEVICE_NAME"),
                "runtime": env("SIMULATOR_RUNTIME_VERSION"),
            ],
            "deviceOrientation": XCUIDevice.shared.orientation.rawValue,
            "window": rect(window.frame),
            "navigationBars": bars(app.navigationBars),
            "tabBars": bars(app.tabBars),
            "toolbars": bars(app.toolbars),
        ]
        try write(name, report, screenshot: app.screenshot())
    }

    /// Each bar's identifier and frame, with its buttons' labels and frames.
    private func bars(_ query: XCUIElementQuery) -> [[String: Any]] {
        query.allElementsBoundByIndex.filter(\.exists).map { bar in
            [
                "identifier": bar.identifier,
                "frame": rect(bar.frame),
                "buttons": bar.buttons.allElementsBoundByIndex.filter(\.exists).map { button in
                    [
                        "label": button.label,
                        "identifier": button.identifier,
                        "frame": rect(button.frame),
                        "hittable": button.isHittable,
                        "selected": button.isSelected,
                    ] as [String: Any]
                },
            ] as [String: Any]
        }
    }

    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(2))
    }

    // MARK: - Output

    private func env(_ key: String) -> String {
        ProcessInfo.processInfo.environment[key] ?? ""
    }

    private func rect(_ r: CGRect) -> [String: Double] {
        ["x": r.minX, "y": r.minY, "w": r.width, "h": r.height]
    }

    private func write(_ name: String, _ report: [String: Any], screenshot: XCUIScreenshot) throws {
        let json = try JSONSerialization.data(
            withJSONObject: report, options: [.prettyPrinted, .sortedKeys]
        )
        print("DUOPROBE \(name) \(String(decoding: json, as: UTF8.self))")

        let jsonAttachment = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
        jsonAttachment.name = "\(name).json"
        jsonAttachment.lifetime = .keepAlways
        add(jsonAttachment)

        let imageAttachment = XCTAttachment(screenshot: screenshot)
        imageAttachment.name = "\(name).png"
        imageAttachment.lifetime = .keepAlways
        add(imageAttachment)

        let dir = URL(fileURLWithPath: env("DUO_OUT").isEmpty ? NSTemporaryDirectory() : env("DUO_OUT"))
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? json.write(to: dir.appendingPathComponent("\(name).json"))
        try? screenshot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
    }
}
