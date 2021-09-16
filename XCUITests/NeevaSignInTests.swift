// Copyright Neeva. All rights reserved.

import Foundation
import XCTest

class NeevaSignInTests: BaseTestCase {
    override func setUp() {
        launchArguments.append(LaunchArguments.EnableMockAppHost)
        launchArguments.append(LaunchArguments.EnableMockUserInfo)

        // For this test, preset a junk login cookie.
        if testName == "testSignInWithStaleLoginCookie" {
            launchArguments.append("\(LaunchArguments.SetLoginCookie)bad-token")
        }

        super.setUp()
    }

    fileprivate func waitUntilPageLoad(withUrlContaining urlSubstring: String) {
        waitUntilPageLoad()

        // TODO(darin): Flakiness alert! Set an extra long timeout here as `waitForPageLoad()`
        // does not always result in the URL being updated immediately, suggesting that there
        // is perhaps an ordering issue between when we stop the progress bar from animating
        // and when the URL gets updated. That is worth investigating and resolving, so that
        // tests involving navigation can be more reliable.
        waitForValueContains(app.buttons["Address Bar"], value: urlSubstring, timeout: 60.0)

        // Print out this value to help debug test flakiness.
        print("Address Bar:", app.buttons["Address Bar"].value.debugDescription)
    }

    fileprivate func doSignIn() {
        let textField = app.textFields.firstMatch
        XCTAssertEqual("Enter token", textField.placeholderValue)

        UIPasteboard.general.string = "good-token"
        textField.tap()
        textField.press(forDuration: 2)
        app.menus.firstMatch.menuItems["Paste"].tap()

        waitForExistence(app.buttons["Sign in"])
        app.buttons["Sign in"].tap()

        waitUntilPageLoad(withUrlContaining: "mock-neeva-home")

        waitForExistence(app.staticTexts["login cookie: good-token"])

        // Expect first run dialog.
        waitForExistence(app.buttons["Got it!"])
        app.buttons["Got it!"].tap()
    }

    fileprivate func doSignOut() {
        goToSettings()

        waitForExistence(app.cells["Bob, bob@example.com"])
        app.cells["Bob, bob@example.com"].tap()

        waitForExistence(app.buttons["Sign Out"])
        app.buttons["Sign Out"].tap()

        waitForExistence(app.sheets.firstMatch.staticTexts["Sign out of Neeva?"])
        waitForExistence(app.sheets.firstMatch.buttons["Sign Out"])
        app.sheets.firstMatch.buttons["Sign Out"].tap()

        waitForExistence(app.cells["Sign In or Join Neeva"])

        waitForExistence(app.navigationBars.buttons["Done"])
        app.navigationBars.buttons["Done"].tap()

        // Reload to ensure we are bounced to the marketing site.
        waitForExistence(app.buttons["Reload"])
        app.buttons["Reload"].tap()

        waitUntilPageLoad(withUrlContaining: "mock-neeva-signin")
        waitForExistence(app.buttons["Sign in"])
    }

    func testSignInFromPromoCard() {
        // Open a new tsb to show zero query
        newTab()
        waitForExistence(app.buttons["Sign in or Join Neeva"])
        app.buttons["Sign in or Join Neeva"].tap()

        waitForExistence(app.buttons["Sign In"])
        app.buttons["Sign In"].tap()
        
        waitUntilPageLoad(withUrlContaining: "mock-neeva-signin")

        doSignIn()
        doSignOut()
    }

    func testSignInFromSettings() {
        goToSettings()

        waitForExistence(app.cells["Sign In or Join Neeva"])
        app.cells["Sign In or Join Neeva"].tap()

        waitForExistence(app.buttons["Sign In"])
        app.buttons["Sign In"].tap()

        waitUntilPageLoad(withUrlContaining: "mock-neeva-signin")

        doSignIn()
        doSignOut()
    }

    func testSignInWithStaleLoginCookie() {
        // See the setUp() function where the stale login cookie is specified
        // as a launch argument to the browser.

        // Load Neeva Home, and we should get redirected to the sign in page.
        waitForExistence(app.buttons["Neeva Menu"])
        app.buttons["Neeva Menu"].tap(force: true)

        waitForExistence(app.buttons["Home"])
        app.buttons["Home"].tap()

        waitUntilPageLoad(withUrlContaining: "mock-neeva-signin")

        doSignIn()
        doSignOut()
    }
}
