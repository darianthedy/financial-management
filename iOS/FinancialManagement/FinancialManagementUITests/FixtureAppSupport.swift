import XCTest

/// Shared steps for the XCUITests that run against the fixture backend.
///
/// `DUO_FIXTURES=1` in the app's launch environment makes the Debug build
/// answer every request from `FixtureStore` and start signed in
/// (Debug/FixtureURLProtocol.swift), so these tests need no network, no
/// credentials and no keychain. The scheme's Test action sets the variable for
/// the test runner only, so it is passed to the app here.
extension XCTestCase {
    /// Launches the app on the fixture backend, in portrait, and waits for the
    /// tab bar.
    @discardableResult
    func launchFixtureApp(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["DUO_FIXTURES"] = "1"
        app.launch()
        waitForTabs(15, in: app, file: file, line: line)
        return app
    }

    /// The SF Symbol of each tab (AppSection.systemImage, ContentRootView),
    /// including the sidebar-only sections that must not show up as tabs.
    /// A rail button's accessibility identifier is its symbol's name.
    private static let tabSymbols: [String: String] = [
        "Dashboard": "square.grid.2x2",
        "Accounts": "wallet.bifold",
        "Transactions": "arrow.left.arrow.right",
        "Budgets": "target",
        "More": "ellipsis",
        "Tags": "tag",
        "Settings": "gear",
    ]

    /// The root's tab buttons. On the iPhone Duo's outer display the system
    /// draws the tab bar as a vertical rail, which the accessibility tree
    /// exposes as plain buttons (in a Toolbar) with no TabBar element; there
    /// they are matched by their symbol, so a pushed screen's "Accounts" back
    /// button never stands in for the Accounts tab.
    func tabButtons(in app: XCUIApplication) -> XCUIElementQuery {
        if app.tabBars.firstMatch.exists { return app.tabBars.buttons }
        return app.buttons.matching(
            NSPredicate(format: "identifier IN %@", Array(Self.tabSymbols.values))
        )
    }

    /// The root's tab button for `name` (Dashboard, Accounts, …), in a tab
    /// bar or on the outer display's rail.
    func tab(_ name: String, in app: XCUIApplication) -> XCUIElement {
        tabButtons(in: app).matching(NSPredicate(format: "label == %@", name)).firstMatch
    }

    /// Waits for the root's tabs, in a tab bar or on the rail. Polls both, as
    /// which one shows is only known once the root is up.
    func waitForTabs(
        _ timeout: TimeInterval, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let rail = app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier == %@", "Dashboard", Self.tabSymbols["Dashboard"]!)
        ).firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if app.tabBars.firstMatch.exists || rail.exists { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        } while Date() < deadline
        dumpScreen(app)
        XCTFail("Timed out after \(Int(timeout))s waiting for the tab bar or rail", file: file, line: line)
    }

    /// Selects the tab `name`, and pops its stack to its root screen (titled
    /// `rootTitle`, the tab's name by default): the scene may have restored a
    /// pushed screen from an earlier launch.
    func openTab(
        _ name: String, rootTitle: String? = nil, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let button = tab(name, in: app)
        waitUntilExists(button, 10, in: app, file: file, line: line)
        button.tap()
        let root = app.navigationBars[rootTitle ?? name]
        for _ in 0..<4 where !root.waitForExistence(timeout: 2) {
            let back = app.navigationBars.buttons.firstMatch
            guard back.exists else { break }
            back.tap()
        }
        waitUntilExists(root, 5, in: app, file: file, line: line)
    }

    /// The first button whose label contains `text` and that can be tapped
    /// now. Rows combine their texts into one label ("Jenius, Digital Wallet,
    /// Rp…"), and a screen in another tab may carry the same text off screen.
    func hittableButton(
        containing text: String, in app: XCUIApplication, timeout: TimeInterval = 10,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let query = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text))
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let hit = query.allElementsBoundByIndex.first(where: { $0.exists && $0.isHittable }) {
                return hit
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        } while Date() < deadline
        dumpScreen(app)
        XCTFail("No hittable button containing \"\(text)\" after \(Int(timeout))s", file: file, line: line)
        return query.firstMatch
    }

    /// A pushed screen's back button: labelled "Back" or with the previous
    /// screen's title, the leading button of its navigation bar.
    func backButton(of bar: XCUIElement, previous: String) -> XCUIElement {
        let labelled = bar.buttons.matching(
            NSPredicate(format: "label == %@ OR label == %@ OR identifier == %@", "Back", previous, "BackButton")
        ).firstMatch
        return labelled.exists ? labelled : bar.buttons.element(boundBy: 0)
    }

    /// Rotates the device and lets the layout settle.
    func rotate(_ orientation: UIDeviceOrientation, in app: XCUIApplication) {
        XCUIDevice.shared.orientation = orientation
        // The window's frame follows the rotation once it has finished.
        let landscape = orientation.isLandscape
        let deadline = Date().addingTimeInterval(5)
        repeat {
            let frame = app.windows.firstMatch.frame
            if !frame.isEmpty, (frame.width > frame.height) == landscape { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        } while Date() < deadline
        RunLoop.current.run(until: Date().addingTimeInterval(1))
    }

    /// Waits for `element`; on a miss, logs what was on screen (the CI log is
    /// all a failed run leaves to read) and attaches a screenshot.
    func waitUntilExists(
        _ element: XCUIElement, _ timeout: TimeInterval, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard !element.waitForExistence(timeout: timeout) else { return }
        dumpScreen(app)
        XCTFail("Timed out after \(Int(timeout))s waiting for \(element)", file: file, line: line)
    }

    /// Prints the accessibility tree and attaches a screenshot.
    func dumpScreen(_ app: XCUIApplication) {
        print("UITEST-SCREEN-BEGIN\n\(app.debugDescription)\nUITEST-SCREEN-END")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.lifetime = .keepAlways
        add(shot)
    }
}
