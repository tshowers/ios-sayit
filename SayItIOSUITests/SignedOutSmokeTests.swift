import XCTest

/// Read-only smoke test of the signed-out experience against the live feed:
/// browse, open a post in isolation, and check that every action that needs
/// an account asks for sign-in instead of failing. Nothing is written.
final class SignedOutSmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testBrowseAndOpenAPost() {
        XCTAssertTrue(app.navigationBars["Say It"].waitForExistence(timeout: 10))

        let firstPost = app.collectionViews.cells.firstMatch
        XCTAssertTrue(firstPost.waitForExistence(timeout: 20), "The feed should load posts for signed-out visitors")
        firstPost.tap()

        XCTAssertTrue(app.navigationBars["Post"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Comments"].waitForExistence(timeout: 10) || app.staticTexts["COMMENTS"].exists)
        XCTAssertTrue(app.textFields["Sign in to join the conversation"].exists || app.textViews["Sign in to join the conversation"].exists)
        XCTAssertTrue(app.buttons["Share"].exists)

        let interested = app.buttons["I'm interested"]
        if interested.exists {
            interested.tap()
            XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5), "Signed out, 'I'm interested' should open sign-in")
            app.buttons["Cancel"].tap()
        }
    }

    func testComposeAsksForSignIn() {
        XCTAssertTrue(app.navigationBars["Say It"].waitForExistence(timeout: 10))
        app.buttons["New post"].tap()
        XCTAssertTrue(app.staticTexts["Say It"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Cancel"].exists)
    }

    func testInboxAndMeTabsInviteSignIn() {
        app.tabBars.buttons["Interest"].tap()
        XCTAssertTrue(app.staticTexts["Your interest inbox"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Sign In"].exists)

        app.tabBars.buttons["Me"].tap()
        XCTAssertTrue(app.staticTexts["Get found on Say It"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Community Guidelines"].exists)
    }
}
