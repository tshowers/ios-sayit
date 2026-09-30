import XCTest

/// Signed-out smoke tests against the live feed: the first-launch wizard
/// (including the layout choice), the one-post-at-a-time feed in each
/// layout, the top tabs, and account-only actions pushing sign-in instead
/// of failing or popping up. Nothing is written.
final class SignedOutSmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Fresh install; optionally browsing already, in a given layout.
    private func launch(browsing: Bool = false, layout: String? = nil) {
        // Launch arguments win over anything an earlier test saved.
        app.launchArguments = ["-uiTestFreshInstall", "-sayit.browsingAsGuest", browsing ? "YES" : "NO"]
        if let layout { app.launchArguments += ["-sayit.feedLayout", layout] }
        app.launch()
    }

    private func next() { app.buttons["Next"].tap() }

    func testWizardWritesAPostPicksALayoutAndEndsAtSignIn() {
        launch()
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

        XCTAssertTrue(app.staticTexts["How should posts look?"].waitForExistence(timeout: 5))
        let ribbon = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Ribbon'")).firstMatch
        ribbon.tap()
        XCTAssertTrue(ribbon.isSelected)
        next()

        // Reaching sign-in earns The Opener - celebrated here, synced after sign-in.
        if app.buttons["Continue"].waitForExistence(timeout: 5) { app.buttons["Continue"].tap() }
        XCTAssertTrue(app.staticTexts["Last step: sign in to post it"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Step 4 of 4"].exists)
        XCTAssertTrue(app.buttons["Read the Community Guidelines"].exists)
    }

    func testJustBrowseOpensTheFullScreenFeed() {
        launch()
        XCTAssertTrue(app.buttons["Just browse"].waitForExistence(timeout: 10))
        app.buttons["Just browse"].tap()
        XCTAssertTrue(app.staticTexts["SayIt"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["For you"].exists)
        XCTAssertTrue(app.buttons["Orgs"].exists)
        XCTAssertTrue(app.buttons["Inbox"].exists)
    }

    func testRibbonLayoutPagesWithASwipe() {
        launch(browsing: true, layout: "1c")
        let counter = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '1 / '")).firstMatch
        XCTAssertTrue(counter.waitForExistence(timeout: 20), "The live feed loads for signed-out visitors")
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '2 / '")).firstMatch.waitForExistence(timeout: 5))
        app.swipeRight()
        XCTAssertTrue(counter.waitForExistence(timeout: 5))
    }

    func testEachLayoutShowsInterestedAndItNeedsSignIn() {
        for layout in ["1a", "1b", "1c"] {
            app.terminate()
            launch(browsing: true, layout: layout)
            XCTAssertTrue(app.staticTexts["SayIt"].waitForExistence(timeout: 10), layout)
            // Neighboring posts are rendered off-screen, so use the visible button.
            // The first post may be a TODD system post with no author; page until one has it.
            func visibleInterested() -> XCUIElement? {
                app.buttons.matching(identifier: "I'm interested").allElementsBoundByIndex.first { $0.exists && $0.isHittable }
            }
            _ = app.buttons["I'm interested"].firstMatch.waitForExistence(timeout: 10)
            var tries = 0
            while visibleInterested() == nil && tries < 5 {
                app.swipeLeft()
                tries += 1
            }
            guard let interested = visibleInterested() else {
                return XCTFail("\(layout) should show I'm interested")
            }
            interested.tap()
            XCTAssertTrue(app.staticTexts["Sign in to Say It"].waitForExistence(timeout: 5), "\(layout): signed out, interest pushes sign-in")
        }
    }

    /// iPad landscape used to push the post off screen entirely.
    func testWholePostIsVisibleInEveryOrientation() throws {
        launch(browsing: true, layout: "1b")
        XCTAssertTrue(app.staticTexts["SayIt"].waitForExistence(timeout: 10))
        let orientations: [UIDeviceOrientation] = UIDevice.current.userInterfaceIdiom == .pad ? [.portrait, .landscapeLeft] : [.portrait]
        for orientation in orientations {
            XCUIDevice.shared.orientation = orientation
            // Let the rotation finish and the feed re-lay out before checking.
            Thread.sleep(forTimeInterval: 2)
            let visible = app.buttons.matching(identifier: "I'm interested").allElementsBoundByIndex.first { $0.exists && $0.isHittable }
                ?? app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Like'")).allElementsBoundByIndex.first { $0.exists && $0.isHittable }
            XCTAssertNotNil(visible, "The post's actions should be on screen in \(orientation.rawValue)")
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "feed-\(orientation.rawValue)"
            shot.lifetime = .keepAlways
            add(shot)
        }
        XCUIDevice.shared.orientation = .portrait
    }

    func testNewPostWhileBrowsingGoesBackToTheWizard() {
        launch(browsing: true)
        XCTAssertTrue(app.buttons["New post"].waitForExistence(timeout: 10))
        app.buttons["New post"].tap()
        XCTAssertTrue(app.staticTexts["What brings you to Say It?"].waitForExistence(timeout: 5))
    }

    func testOrgsInboxAndProfileAskGuestsToSignIn() {
        launch(browsing: true)
        XCTAssertTrue(app.buttons["Inbox"].waitForExistence(timeout: 10))
        app.buttons["Inbox"].tap()
        XCTAssertTrue(app.staticTexts["Your inbox"].waitForExistence(timeout: 5))

        app.buttons["Orgs"].tap()
        XCTAssertTrue(app.staticTexts["Organizations"].waitForExistence(timeout: 5))
        app.buttons["Sign in"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Sign in to Say It"].waitForExistence(timeout: 5))
    }
}
