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

        // 2. Land on the tab bar and open Accounts.
        let accountsTab = tab("Accounts", in: app)
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
        tab("Transactions", in: app).tap()
        app.buttons["Add"].firstMatch.tap()
        // Saving needs an account: pick the one just added.
        let accountPicker = app.buttons["Account"].firstMatch
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
        tab("Dashboard", in: app).tap()
        waitFor(app.staticTexts["Planned Expenses"], 10, in: app)
    }

    /// A root tab's button. On the Duo's outer display the tab bar is a
    /// vertical rail, and with adaptive layouts on (D7.1) a regular-width
    /// scene shows a sidebar instead, so fall back to any button of that name.
    private func tab(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let bar = app.tabBars.buttons[name]
        return bar.exists ? bar : app.buttons[name].firstMatch
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
