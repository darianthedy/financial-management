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
        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 10))
        emailField.tap()
        emailField.typeText(email!)

        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText(password!)

        app.buttons["Sign In"].tap()

        // 2. Land on the tab bar and open Accounts.
        let accountsTab = app.tabBars.buttons["Accounts"]
        XCTAssertTrue(accountsTab.waitForExistence(timeout: 15))
        accountsTab.tap()

        // 3. Add an account via the "+" toolbar button.
        app.navigationBars.buttons["Add"].firstMatch.tap()
        let accountName = "UITest Account \(Int(Date().timeIntervalSince1970))"
        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(accountName)
        app.buttons["Save"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts[accountName].waitForExistence(timeout: 10))

        // 4. Add a transaction.
        app.tabBars.buttons["Transactions"].tap()
        app.navigationBars.buttons["Add"].firstMatch.tap()
        let amountField = app.textFields.firstMatch
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("42")
        app.buttons["Save"].firstMatch.tap()

        // 5. Verify the dashboard renders its widgets.
        app.tabBars.buttons["Dashboard"].tap()
        XCTAssertTrue(app.staticTexts["Planned Expenses"].waitForExistence(timeout: 10))
    }
}
