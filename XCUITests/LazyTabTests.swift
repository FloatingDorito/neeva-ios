// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest

class LazyTabTests: BaseTestCase {
    func testCancelURLBarReturnsToWebsite() {
        openURLInNewTab()
        waitForExistence(app.staticTexts["Example Domain"])

        app.buttons["Address Bar"].tap()
        waitForExistence(app.buttons["Cancel"])
        app.buttons["Cancel"].tap()

        // Confirms the app returns to the web page
        waitForExistence(app.staticTexts["Example Domain"])
    }

    // MARK: Tab Tray
    func testNoTabAddedWhenCancelingNewTabFromTabTray() {
        goToTabTray()

        app.buttons["Add Tab"].tap()

        waitForExistence(app.buttons["Cancel"])
        app.buttons["Cancel"].tap()

        // Confirms the app returns to the tab tray
        waitForExistence(app.buttons["Add Tab"])
    }

    func testLazyTabCreatedFromTabTray() {
        goToTabTray()

        app.buttons["Add Tab"].tap()
        waitForExistence(app.buttons["Cancel"])
        openURL()

        XCTAssertEqual(getNumberOfTabs(), 2)
    }

    // MARK: Long Press Tab Tray Button
    func testNoTabAddedWhenCancelingNewTabFromLongPressTabTrayButton() {
        newTab()

        app.buttons["Cancel"].tap()

        // Confirms that no tab was created
        XCTAssertEqual(getNumberOfTabs(), 1)
    }

    func testLazyTabCreatedFromLongPressTabTrayButton() {
        newTab()
        openURL()

        XCTAssertEqual(getNumberOfTabs(), 2)
    }

    // MARK: Incognito Mode
    func testNoTabAddedWhenCancelingNewTabFromIncognito() {
        goToTabTray()
        setIncognitoMode(enabled: true, shouldOpenURL: false, closeTabTray: false)

        newTab()
        waitForExistence(app.buttons["Cancel"])
        app.buttons["Cancel"].tap()

        // Confirms that the tab tray is open and that the incognito mode is still enabled.
        waitForExistence(app.staticTexts["Incognito Tabs"])
        waitForExistence(app.staticTexts["EmptyTabTrayIncognito"])
    }

    func testLazyTabCreatedFromIncognito() {
        openURLInNewTab(path(forTestPage: "test-mozilla-book.html"))
        setIncognitoMode(enabled: true)

        // confirms incognito tab was created
        XCTAssertEqual(getNumberOfTabs(), 1)
    }

    func testLazyTabNotCreatedWhenIncognitoTabOpen() {
        // create normal tab and open incognito tab
        openURLInNewTab(path(forTestPage: "test-mozilla-book.html"))
        setIncognitoMode(enabled: true)

        // switch back to normal mode
        goToTabTray()
        setIncognitoMode(enabled: false, closeTabTray: false)

        // switch back to incognito mode
        setIncognitoMode(enabled: true, shouldOpenURL: false, closeTabTray: false)

        // confirms that non-incognito tab is shown
        XCTAssert(!app.buttons["Cancel"].exists)
        waitForExistence(app.buttons["Example Domain, Tab"])
    }
}
