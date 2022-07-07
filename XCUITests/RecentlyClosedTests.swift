// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest

class RecentlyClosedTests: BaseTestCase {
    private func showRecentlyClosedTabs() {
        goToTabTray()
        app.buttons["Add Tab"].press(forDuration: 1)
    }

    func testRecentlyClosedOptionAvailable() {
        // Now go back to default website close it and check whether the option is enabled
        openURL(path(forTestPage: "test-mozilla-book.html"))
        waitUntilPageLoad()
        closeAllTabs()

        goToRecentlyClosedPage()

        // The Closed Tabs list should contain the info of the website just closed
        waitForExistence(app.scrollViews["recentlyClosedPanel"])
        waitForExistence(app.buttons["The Book of Mozilla"])
        app.buttons["History"].tap()
        app.buttons["Done"].tap()

        // This option should be enabled on private mode too
        setIncognitoMode(enabled: true)

        goToRecentlyClosedPage()
        waitForExistence(app.scrollViews["recentlyClosedPanel"])
    }

    func testClearRecentlyClosedHistory() {
        // Open the default website
        openURL(path(forTestPage: "test-mozilla-book.html"))
        waitUntilPageLoad()
        closeAllTabs()

        goToRecentlyClosedPage()

        // Once the website is visited and closed it will appear in Recently Closed Tabs list
        waitForExistence(app.scrollViews["recentlyClosedPanel"])
        waitForExistence(app.buttons["The Book of Mozilla"])
        app.buttons["History"].tap()
        app.buttons["Done"].tap()

        clearPrivateData()
        goToHistory()

        // Check history/recently closed items are cleared
        waitForExistence(app.staticTexts["History List Empty"])
    }

    func testRecentlyClosedMenuAvailable() {
        openURL(path(forTestPage: "test-mozilla-book.html"))
        waitUntilPageLoad()
        closeAllTabs()

        showRecentlyClosedTabs()
        XCTAssertTrue(app.buttons["The Book of Mozilla"].exists)
    }

    // MARK: - Open in New Tab
    func testOpenInNewTabRecentlyClosedItemFromMenu() {
        // test the recently closed tab menu
        openURL(path(forTestPage: "test-mozilla-book.html"))
        waitUntilPageLoad()
        closeAllTabs()

        showRecentlyClosedTabs()
        app.buttons["The Book of Mozilla"].tap()

        XCTAssertEqual(getNumberOfTabs(openTabTray: false), 2)
    }

    func testOpenInNewTabRecentlyClosedItem() {
        // Test the recently closed tab page
        openURL(path(forTestPage: "test-mozilla-book.html"))
        waitUntilPageLoad()
        closeAllTabs()

        goToRecentlyClosedPage()

        waitForExistence(app.scrollViews["recentlyClosedPanel"])
        app.buttons["The Book of Mozilla"].press(forDuration: 1)
        app.buttons["Open in new tab"].tap()
        app.buttons["History"].tap()
        app.buttons["Done"].tap()

        XCTAssertEqual(getNumberOfTabs(), 2)
    }

    func testOpenInNewIncognitoTabRecentlyClosedItem() {
        // Open the default website
        openURLInNewTab(path(forTestPage: "test-mozilla-book.html"))
        waitUntilPageLoad()
        closeAllTabs()

        goToRecentlyClosedPage()

        waitForExistence(app.scrollViews["recentlyClosedPanel"])
        app.buttons["The Book of Mozilla"].press(forDuration: 1)
        app.buttons["Open in new incognito tab"].tap()
        app.buttons["History"].tap()
        app.buttons["Done"].tap()

        goToTabTray()
        setIncognitoMode(enabled: true, shouldOpenURL: false, closeTabTray: false)

        XCTAssertEqual(getNumberOfTabs(openTabTray: false), 1)
    }

    func testIncognitoClosedSiteDoesNotAppearOnRecentlyClosedMenu() {
        setIncognitoMode(enabled: true)

        // Open the default website
        openURL(path(forTestPage: "test-mozilla-book.html"))
        waitUntilPageLoad()
        closeAllTabs()

        showRecentlyClosedTabs()
        XCTAssertFalse(app.buttons["The Book of Mozilla"].exists)
    }

    func testIncognitoClosedSiteDoesNotAppearOnRecentlyClosed() {
        setIncognitoMode(enabled: true)

        // Open the default website
        openURL(path(forTestPage: "test-mozilla-book.html"))
        waitUntilPageLoad()
        closeAllTabs()

        goToHistory()

        waitForExistence(app.staticTexts["History List Empty"])
    }
}
