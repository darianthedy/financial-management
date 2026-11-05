import XCTest

/// Happy-path integration flow (§13): login → add account → add transaction →
/// verify the dashboard reflects it.
///
/// The flow needs a live Supabase backend and real credentials, so it is gated
/// behind launch-environment variables and **skips** (rather than fails) when
/// they are absent. To run it:
///
///   xcodebuild test -scheme "FinancialManagement (Dev)" \
///     -only-testing:FinancialManagementUITests \
///     UITEST_EMAIL=… UITEST_PASSWORD=…
///
/// (pass the credentials through the scheme's Test action environment).
final class HappyPathUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testLoginAddAccountAddTransactionVerifyDashboard() throws {
        let env = ProcessInfo.processInfo.environment
        let email = env["UITEST_EMAIL"]
        let password = env["UITEST_PASSWORD"]
        try XCTSkipUnless(
            email != nil && password != nil,
            "Set UITEST_EMAIL / UITEST_PASSWORD to run the live happy-path flow."
        )

        let app = XCUIApplication()
        app.launch()

        // 1. Login.
        let emailField = app.textFields["you@example.com"]
        waitFor(emailField, 10, in: app)
        emailField.tap()
        emailField.typeText(email!)

        let passwordField = app.secureTextFields.firstMatch
        passwordField.tap()
        passwordField.typeText(password!)

        app.buttons["Sign in"].tap()

        // 2. Land on the Dashboard and open the Accounts tab.
        let accountsTab = section("Accounts", in: app)
        waitFor(accountsTab, 15, in: app)
        accountsTab.tap()

        // 3. Add an account via the "+" toolbar button.
        app.buttons["Add"].firstMatch.tap()
        let accountName = "UITest Account \(Int(Date().timeIntervalSince1970))"
        let nameField = app.textFields.firstMatch
        waitFor(nameField, 5, in: app)
        nameField.tap()
        nameField.typeText(accountName)
        app.buttons["Save"].firstMatch.tap()
        // The sheet closes only on success; a save error keeps it up, with
        // the new row possibly visible behind it.
        let accountSheet = app.navigationBars["New Account"]
        if !accountSheet.waitForNonExistence(timeout: 10) {
            print("HAPPYPATH-SCREEN-BEGIN\n\(app.debugDescription)\nHAPPYPATH-SCREEN-END")
            XCTFail("The New Account sheet didn't close after Save")
        }
        waitFor(app.staticTexts[accountName], 10, in: app)

        // 4. Add a transaction.
        section("Transactions", in: app).tap()
        app.buttons["Add"].firstMatch.tap()
        // Saving needs an account: pick the one just added.
        // A menu picker's label carries its value: "Account, Select Account".
        let accountPicker = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Account,")).firstMatch
        waitFor(accountPicker, 5, in: app)
        accountPicker.tap()
        let accountOption = app.buttons[accountName].firstMatch
        waitFor(accountOption, 10, in: app)
        accountOption.tap()
        let amountField = app.textFields["0"].firstMatch
        waitFor(amountField, 5, in: app)
        amountField.tap()
        amountField.typeText("42")
        let save = app.buttons["Save"].firstMatch
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10))

        // 5. Verify the dashboard renders its widgets.
        section("Dashboard", in: app).tap()
        waitFor(app.staticTexts["Planned Expenses"], 10, in: app)
    }

    /// A section's button in the root's tab bar, the same five tabs on every
    /// display (docs/ios-tab-root-plan.md).
    private func section(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.tabBars.buttons[name]
    }

    /// Waits for `element`; on a miss, logs what was on screen (the CI log is
    /// all a failed T3 run leaves to read) and attaches a screenshot.
    private func waitFor(
        _ element: XCUIElement, _ timeout: TimeInterval, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard !element.waitForExistence(timeout: timeout) else { return }
        print("HAPPYPATH-SCREEN-BEGIN\n\(app.debugDescription)\nHAPPYPATH-SCREEN-END")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.lifetime = .keepAlways
        add(shot)
        XCTFail("Timed out after \(Int(timeout))s waiting for \(element)", file: file, line: line)
    }
}
