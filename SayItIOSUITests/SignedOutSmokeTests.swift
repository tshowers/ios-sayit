import XCTest

/// Signed-out smoke tests against the live feed: the first-launch wizard,
/// browsing, and every account-only action pushing the sign-in page
/// instead of failing or popping up. Nothing is written.
final class SignedOutSmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFreshInstall"]
        app.launch()
    }

    private func next() { app.buttons["Next"].tap() }

    func testWizardWritesAPostFromDefaultsAndEndsAtSignIn() {
        XCTAssertTrue(app.staticTexts["What brings you to Say It?"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Step 2 of 4"].exists, "Download counts as step 1")
        XCTAssertTrue(app.buttons["I'm looking for something"].isSelected)

        next()
        XCTAssertTrue(app.staticTexts["What are you looking for?"].waitForExistence(timeout: 5))
        app.buttons["Referrals"].tap()
        next()

        XCTAssertTrue(app.staticTexts["Which industry?"].waitForExistence(timeout: 5))
        app.buttons["wizard-category"].tap()
        app.buttons["Construction"].tap()
        next()

        XCTAssertTrue(app.staticTexts["Here's your post"].waitForExistence(timeout: 5))
        let post = app.textViews["wizard-post"].exists ? app.textViews["wizard-post"] : app.textFields["wizard-post"]
        XCTAssertEqual(post.value as? String, "Looking for referrals in construction. Any recommendations?")
        next()

        XCTAssertFalse(app.buttons["Next"].isEnabled, "First name is required")
        app.textFields["First name"].tap()
        app.textFields["First name"].typeText("Ada")
        next()
        app.textFields["Last name"].tap()
        app.textFields["Last name"].typeText("Lovelace")
        next()
        XCTAssertTrue(app.staticTexts["What's your business called?"].waitForExistence(timeout: 5))
        app.buttons["Skip"].tap()

        // Reaching sign-in earns The Opener - celebrated here, synced after sign-in.
        if app.buttons["Continue"].waitForExistence(timeout: 5) { app.buttons["Continue"].tap() }
        XCTAssertTrue(app.staticTexts["Last step: sign in to post it"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Step 4 of 4"].exists)
        XCTAssertTrue(app.buttons["Read the Community Guidelines"].exists)
    }

    func testJustBrowseOpensTheFeedAndPostsNeedSignInToAct() {
        XCTAssertTrue(app.buttons["Just browse"].waitForExistence(timeout: 10))
        app.buttons["Just browse"].tap()
        XCTAssertTrue(app.navigationBars["Say It"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Say what you need. Get found."].exists)

        let firstPost = app.collectionViews.cells.element(boundBy: 1)
        XCTAssertTrue(firstPost.waitForExistence(timeout: 20), "The feed should load posts for signed-out visitors")
        firstPost.tap()
        XCTAssertTrue(app.navigationBars["Post"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Share"].exists)

        let interested = app.buttons["I'm interested"]
        if interested.waitForExistence(timeout: 3) {
            interested.tap()
            XCTAssertTrue(app.staticTexts["Sign in to Say It"].waitForExistence(timeout: 5), "Signed out, interest pushes the sign-in page")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.navigationBars["Post"].waitForExistence(timeout: 5))
        }
    }

    func testNewPostWhileBrowsingGoesBackToTheWizard() {
        app.buttons["Just browse"].tap()
        XCTAssertTrue(app.navigationBars["Say It"].waitForExistence(timeout: 10))
        app.buttons["New post"].tap()
        XCTAssertTrue(app.staticTexts["What brings you to Say It?"].waitForExistence(timeout: 5))
    }

    func testInterestAndMeTabsPushSignIn() {
        app.buttons["Just browse"].tap()
        app.tabBars.buttons["Interest"].tap()
        XCTAssertTrue(app.staticTexts["Your interest inbox"].waitForExistence(timeout: 5))
        app.buttons["Sign In"].tap()
        XCTAssertTrue(app.staticTexts["Sign in to Say It"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Me"].tap()
        XCTAssertTrue(app.staticTexts["Get found on Say It"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Community Guidelines"].exists)
    }
}
