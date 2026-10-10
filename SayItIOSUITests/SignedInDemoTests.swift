import XCTest

/// Signed-in checks with the App Review demo account, against live data.
/// The credentials come from the environment, never the repo:
///
///     TEST_RUNNER_SAYIT_DEMO_EMAIL=... TEST_RUNNER_SAYIT_DEMO_PASSWORD=... \
///       xcodebuild test ... -only-testing:SayItIOSUITests/SignedInDemoTests
///
/// Skipped when they aren't set. Writes only the demo account's own profile
/// (saved with the values it already has). Never posts, reports or blocks -
/// a report emails the moderator. Screenshots are kept in the test results.
final class SignedInDemoTests: XCTestCase {
    private var app: XCUIApplication!
    private var email = ""
    private var password = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        email = env["SAYIT_DEMO_EMAIL"] ?? ""
        password = env["SAYIT_DEMO_PASSWORD"] ?? ""
        try XCTSkipIf(email.isEmpty || password.isEmpty, "Set SAYIT_DEMO_EMAIL and SAYIT_DEMO_PASSWORD to run.")
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFreshInstall", "-sayit.browsingAsGuest", "NO"]
        app.launch()
    }

    func testDemoAccountSignInProfileFeedAndComposer() {
        signIn()
        snapshot("1-feed-after-sign-in")

        dismissSavePasswordPrompt()
        XCTAssertTrue(app.buttons["For you"].waitForExistence(timeout: 15))

        // Guideline 1.2 actions on someone else's post: swipe past the demo
        // account's own posts (their menu only offers Delete).
        // The pager keeps neighbouring posts loaded off screen, so only
        // count what's visible.
        func visible(_ query: XCUIElementQuery) -> XCUIElement? {
            query.allElementsBoundByIndex.first { $0.exists && $0.isHittable && app.frame.contains($0.frame) }
        }
        for _ in 0..<10 where visible(app.staticTexts.matching(identifier: "appreview")) != nil {
            app.swipeLeft()
            sleep(1)
        }
        XCTAssertNil(visible(app.staticTexts.matching(identifier: "appreview")), "Found a post by someone else")
        guard let more = visible(app.buttons.matching(NSPredicate(format: "label == 'More: comments, report, block'"))) else {
            return XCTFail("No ••• button on the visible post")
        }
        more.tap()
        let menu = app.buttons["More"].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        XCTAssertTrue(app.buttons["Hide Post"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Report Post"].exists)
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Block '")).firstMatch.exists)
        snapshot("2-post-menu")
        // Back to a fresh feed (still signed in).
        app.terminate()
        app.launchArguments = []
        app.launch()

        // The demo account's YouTube post: title instead of the URL, and its thumbnail.
        XCTAssertTrue(app.buttons["Search posts"].waitForExistence(timeout: 10))
        app.buttons["Search posts"].tap()
        let search = app.textFields["Search posts, people, orgs"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Obama")
        let result = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Obama'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10), "The video post shows its title")
        snapshot("3-search-video-post")
        result.tap()
        sleep(8)
        snapshot("4-video-post-in-feed")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'https://youtu'")).firstMatch.exists,
                       "A video link's URL shouldn't show as the headline")
        if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["Your profile"].waitForExistence(timeout: 15))

        // Profile save (was "unauthorized" before the 2026-10-09 backend fix).
        app.buttons["Your profile"].firstMatch.tap()
        let editor = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'appreview'")).firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "Profile row")
        editor.tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 10))
        app.buttons["Save"].tap()
        sleep(5)
        snapshot("5-profile-after-save")
        XCTAssertFalse(app.staticTexts["unauthorized"].exists, "Profile save was refused")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'unable to save'")).firstMatch.exists)

        // Composer: a long link alone doesn't break the 90-character limit.
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["New post"].waitForExistence(timeout: 15))
        app.buttons["New post"].tap()
        let headline = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(headline.waitForExistence(timeout: 10))
        headline.tap()
        headline.typeText("https://www.usatoday.com/story/entertainment/celebrities/2026/10/09/halle-berry-daughter-nahla-aubry/92173323007/")
        snapshot("6-composer-long-link")
        XCTAssertTrue(app.staticTexts["90"].exists, "A link alone uses none of the 90 characters")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH '-'")).firstMatch.exists, "No negative count")
        // Leave without posting.
    }

    private func signIn() {
        // The keychain can keep the session from an earlier run.
        let haveAccount = app.buttons["Already have an account? Sign in"]
        let profile = app.buttons["Your profile"]
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline && !haveAccount.exists && !profile.exists { usleep(250_000) }
        if profile.exists { return }
        XCTAssertTrue(haveAccount.exists)
        haveAccount.tap()

        let agree = app.switches.containing(NSPredicate(format: "label BEGINSWITH 'I agree'")).firstMatch
        XCTAssertTrue(agree.waitForExistence(timeout: 10))
        agree.tap()

        app.buttons["Sign in with email"].tap()
        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(email)
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText(password)
        app.buttons["Sign In"].tap()

        // Reaching sign-in may celebrate an award first.
        if app.buttons["Continue"].waitForExistence(timeout: 10) { app.buttons["Continue"].tap() }
    }

    /// iOS offers to save the password after email sign-in.
    private func dismissSavePasswordPrompt() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for candidate in [app.buttons["Not Now"], springboard.buttons["Not Now"]] where candidate.waitForExistence(timeout: 4) {
            candidate.tap()
            return
        }
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
