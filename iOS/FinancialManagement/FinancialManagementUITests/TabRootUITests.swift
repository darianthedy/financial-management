import XCTest

/// The tab root (docs/ios-tab-root-plan.md, p2) on the fixture backend: the
/// five tabs, More's pushes, and Accounts' list → detail in each layout,
/// including across a rotation.
///
/// Runs wherever the simulator lands. On CI that is the iPhone Duo's outer
/// display, where list | detail never tiles; the tests that need it tiled
/// (regular width, landscape, ≥ 660 pt) skip there and run on an iPad gate.
final class TabRootUITests: XCTestCase {
    private static let tabs = ["Dashboard", "Accounts", "Transactions", "Budgets", "More"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    // MARK: - Tabs

    /// The same five tabs in the tab bar in both orientations, and no
    /// sections sidebar or sidebar toggle.
    func testFiveTabsAndNoSidebar() {
        let app = launchFixtureApp()
        openTab("Dashboard", in: app)
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            rotate(orientation, in: app)
            for name in Self.tabs {
                XCTAssertTrue(tab(name, in: app).waitForExistence(timeout: 5), "\(name) tab, \(orientation.rawValue)")
            }
            XCTAssertEqual(app.tabBars.buttons.count, Self.tabs.count, "tab bar buttons, \(orientation.rawValue)")
            for toggle in ["Show Sidebar", "Hide Sidebar", "Sidebar"] {
                XCTAssertFalse(app.buttons[toggle].exists, "\(toggle) button, \(orientation.rawValue)")
            }
            // The management screens live in More, not in a sidebar beside it.
            XCTAssertFalse(tab("Tags", in: app).exists, "Tags tab, \(orientation.rawValue)")
            XCTAssertFalse(tab("Settings", in: app).exists, "Settings tab, \(orientation.rawValue)")
        }
    }

    // MARK: - More

    /// More → Tags → a tag pushes its transactions; Back returns to Tags.
    func testMoreTagsPushesTagTransactions() {
        let app = launchFixtureApp()
        openTab("More", in: app)

        hittableButton(containing: "Tags", in: app).tap()
        let tags = app.navigationBars["Tags"]
        waitUntilExists(tags, 10, in: app)

        // FixtureStore's "Gifts" tag is on "Dinner with friends".
        hittableButton(containing: "Gifts", in: app).tap()
        let transactions = app.navigationBars["Transactions"]
        waitUntilExists(transactions, 10, in: app)
        waitUntilExists(app.staticTexts["Dinner with friends"], 10, in: app)
        XCTAssertFalse(tags.exists, "Tags is under the pushed list")

        let back = backButton(of: transactions, previous: "Tags")
        XCTAssertTrue(back.exists)
        back.tap()
        waitUntilExists(tags, 5, in: app)
        XCTAssertTrue(transactions.waitForNonExistence(timeout: 5))
        XCTAssertTrue(tab("More", in: app).isSelected)
    }

    /// More → Settings pushes Settings.
    func testMoreSettingsPushes() {
        let app = launchFixtureApp()
        openTab("More", in: app)

        hittableButton(containing: "Settings", in: app).tap()
        let settings = app.navigationBars["Settings"]
        waitUntilExists(settings, 10, in: app)
        XCTAssertTrue(backButton(of: settings, previous: "More").exists)
        XCTAssertFalse(app.navigationBars["More"].exists)
    }

    // MARK: - Accounts list → detail

    /// In portrait (and on the outer display) list | detail never tiles: a row
    /// pushes its detail, with a back button, and Back returns to the list.
    func testAccountsPushesDetailInPortrait() {
        let app = launchFixtureApp()
        openTab("Accounts", in: app)

        hittableButton(containing: "Jenius", in: app).tap()
        let detail = app.navigationBars["Jenius"]
        waitUntilExists(detail, 10, in: app)
        XCTAssertFalse(app.navigationBars["Accounts"].exists, "the list is under the pushed detail")
        let back = backButton(of: detail, previous: "Accounts")
        XCTAssertTrue(back.exists, "Back")

        back.tap()
        waitUntilExists(app.navigationBars["Accounts"], 5, in: app)
        XCTAssertTrue(detail.waitForNonExistence(timeout: 5))
    }

    /// In landscape on regular width with room for both columns, the list
    /// and the selected account's detail are on screen together.
    func testAccountsTilesListAndDetailInLandscape() throws {
        let app = launchFixtureApp()
        try openTiledAccounts(in: app)

        hittableButton(containing: "Jenius", in: app).tap()
        let detail = app.navigationBars["Jenius"]
        waitUntilExists(detail, 10, in: app)
        XCTAssertTrue(app.navigationBars["Accounts"].exists, "list column")
        XCTAssertTrue(hittableButton(containing: "BCA Tahapan", in: app).isHittable, "list rows")
        XCTAssertFalse(app.staticTexts["Select an Account"].exists, "placeholder")
        assertSideBySide(list: app.navigationBars["Accounts"], detail: detail)
    }

    // MARK: - Rotation

    /// An account selected in landscape (tiled) stays selected across a
    /// rotation: pushed in portrait, back in the detail column in landscape
    /// (`SplitSelectionRule`'s `@SceneStorage` restore).
    func testRotationKeepsSelectedAccount() throws {
        let app = launchFixtureApp()
        try openTiledAccounts(in: app)

        hittableButton(containing: "Jenius", in: app).tap()
        waitUntilExists(app.navigationBars["Jenius"], 10, in: app)

        rotate(.portrait, in: app)
        let pushed = app.navigationBars["Jenius"]
        waitUntilExists(pushed, 10, in: app)
        XCTAssertFalse(app.navigationBars["Accounts"].exists, "portrait pushes the detail")
        XCTAssertTrue(backButton(of: pushed, previous: "Accounts").exists, "Back")

        rotate(.landscapeLeft, in: app)
        let tiled = app.navigationBars["Jenius"]
        waitUntilExists(tiled, 10, in: app)
        waitUntilExists(app.navigationBars["Accounts"], 5, in: app)
        XCTAssertFalse(app.staticTexts["Select an Account"].exists, "placeholder")
        assertSideBySide(list: app.navigationBars["Accounts"], detail: tiled)
    }

    /// Where list | detail doesn't tile (the outer display), a pushed account
    /// stays pushed across a rotation and back.
    func testRotationKeepsPushedAccount() {
        let app = launchFixtureApp()
        openTab("Accounts", in: app)

        hittableButton(containing: "Jenius", in: app).tap()
        waitUntilExists(app.navigationBars["Jenius"], 10, in: app)

        rotate(.landscapeLeft, in: app)
        // Tiled (iPad), the pushed row is not a selection: the split shows
        // the list, which `testRotationKeepsSelectedAccount` covers.
        let tiles = app.staticTexts["Select an Account"].waitForExistence(timeout: 2)
        if !tiles {
            waitUntilExists(app.navigationBars["Jenius"], 10, in: app)
        }

        rotate(.portrait, in: app)
        if !tiles {
            waitUntilExists(app.navigationBars["Jenius"], 10, in: app)
            XCTAssertTrue(backButton(of: app.navigationBars["Jenius"], previous: "Accounts").exists)
        }
    }

    /// Transactions' Add sheet stays open through a rotation and back
    /// (`foldSafeSheet`).
    func testRotationKeepsAddSheetOpen() {
        let app = launchFixtureApp()
        openTab("Transactions", in: app)

        let add = app.navigationBars["Transactions"].buttons["Add"]
        waitUntilExists(add, 10, in: app)
        add.tap()
        let sheet = app.navigationBars["New Transaction"]
        waitUntilExists(sheet, 10, in: app)

        rotate(.landscapeLeft, in: app)
        waitUntilExists(sheet, 5, in: app)
        rotate(.portrait, in: app)
        waitUntilExists(sheet, 5, in: app)

        sheet.buttons["Cancel"].tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
    }

    // MARK: - Helpers

    /// Accounts at its list in landscape, nothing selected; skips unless the
    /// split tiles here (its "Select an Account" placeholder shows).
    private func openTiledAccounts(in app: XCUIApplication) throws {
        // Popping to the list in portrait clears a selection restored from
        // an earlier launch, so landscape opens on the placeholder.
        openTab("Accounts", in: app)
        rotate(.landscapeLeft, in: app)
        let frame = app.windows.firstMatch.frame
        try XCTSkipUnless(
            frame.width > frame.height && frame.width >= 660,
            "list | detail needs a landscape window ≥ 660 pt wide; this one is \(frame.size)"
        )
        try XCTSkipUnless(
            app.staticTexts["Select an Account"].waitForExistence(timeout: 5),
            "list | detail doesn't tile here (compact width)"
        )
        waitUntilExists(app.navigationBars["Accounts"], 5, in: app)
    }

    /// The list column is left of the detail column, without overlap.
    private func assertSideBySide(
        list: XCUIElement, detail: XCUIElement, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertLessThanOrEqual(list.frame.maxX, detail.frame.minX + 1, "list | detail", file: file, line: line)
    }
}
