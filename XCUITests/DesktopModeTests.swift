/* This Source Code Form is subject to the terms of the Mozilla Public
 License, v. 2.0. If a copy of the MPL was not distributed with this
 file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest

// Tests for both platforms
class DesktopModeTestsIpad: IpadOnlyTestCase {
    func testLongPressReload() throws {
        try skipIfNeeded()

        openURL(path(forTestPage: "test-user-agent.html"))
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "DESKTOP_UA").count > 0)

        requestMobileSite()
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "MOBILE_UA").count > 0)

        // Covering scenario that when reloading the page should preserve Desktop site
        app.buttons["Reload"].tap()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "MOBILE_UA").count > 0)

        closeAllTabs()

        // Covering scenario that when closing a tab and re-opening should preserve Mobile mode
        openURLInNewTab(path(forTestPage: "test-user-agent.html"))
        XCTAssert(app.webViews.staticTexts.matching(identifier: "MOBILE_UA").count > 0)
    }
}

class DesktopModeTestsIphone: IphoneOnlyTestCase {
    func testClearPrivateData() throws {
        try skipIfNeeded()

        openURL(path(forTestPage: "test-user-agent.html"))
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "MOBILE_UA").count > 0)
        requestDesktopSite()
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "DESKTOP_UA").count > 0)

        // Go to Clear Data
        clearPrivateData()

        // Tab #2
        openURLInNewTab(path(forTestPage: "test-user-agent.html"))
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "MOBILE_UA").count > 0)
    }

    func testSameHostInMultipleTabs() throws {
        try skipIfNeeded()

        openURL(path(forTestPage: "test-user-agent.html"))
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "MOBILE_UA").count > 0)
        requestDesktopSite()
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "DESKTOP_UA").count > 0)

        // Tab #2
        openURLInNewTab(path(forTestPage: "test-user-agent.html"))
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "DESKTOP_UA").count > 0)
        requestMobileSite()
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "MOBILE_UA").count > 0)

        // Tab #3
        openURLInNewTab(path(forTestPage: "test-user-agent.html"))

        XCTAssert(app.webViews.staticTexts.matching(identifier: "MOBILE_UA").count > 0)
    }

    // Smoketest
    func testChangeModeInSameTab() throws {
        try skipIfNeeded()

        openURL(path(forTestPage: "test-user-agent.html"))
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "MOBILE_UA").count > 0)
        requestDesktopSite()
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "DESKTOP_UA").count > 0)

        requestMobileSite()
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "MOBILE_UA").count > 0)
    }

    func testIncognitoModeOffAlsoRemovesFromNormalMode() throws {
        try skipIfNeeded()

        openURLInNewTab(path(forTestPage: "test-user-agent.html?1"))
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "MOBILE_UA").count > 0)
        requestDesktopSite()
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "DESKTOP_UA").count > 0)

        // is now on in normal mode
        setIncognitoMode(enabled: true, urlToOpen: path(forTestPage: "test-user-agent.html"))
        // Workaround to be sure the snackbar dissapers
        reloadPage()
        requestMobileSite()
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "MOBILE_UA").count > 0)

        // is now off in incognito, mode, confirm it is off in a new normal mode
        setIncognitoMode(enabled: false, closeTabTray: false)
        app.buttons["Add Tab"].tap()
        openURL(path(forTestPage: "test-user-agent.html?2"))
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "MOBILE_UA").count > 0)
    }

    func testIncognitoModeOnHasNoAffectOnNormalMode() throws {
        try skipIfNeeded()

        openURL(path(forTestPage: "test-user-agent.html"))
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "MOBILE_UA").count > 0)

        setIncognitoMode(enabled: true)
        openURL(path(forTestPage: "test-user-agent.html"))

        waitUntilPageLoad()
        // Workaround
        reloadPage()
        requestDesktopSite()
        waitUntilPageLoad()
        XCTAssert(app.webViews.staticTexts.matching(identifier: "DESKTOP_UA").count > 0)

        setIncognitoMode(enabled: false, closeTabTray: false)
        app.buttons["Add Tab"].tap()
        openURL(path(forTestPage: "test-user-agent.html"))
        waitUntilPageLoad()

        XCTAssert(app.webViews.staticTexts.matching(identifier: "MOBILE_UA").count > 0)
    }
}
