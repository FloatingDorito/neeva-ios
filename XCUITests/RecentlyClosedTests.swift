// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest

class RecentlyClosedTests: BaseTestCase {
    override func setUp() {
        // For the current test name, add the db fixture used
        launchArguments = [
            LaunchArguments.SkipIntro, LaunchArguments.SkipWhatsNew,
            LaunchArguments.SkipETPCoverSheet, LaunchArguments.DontAddTabOnLaunch,
        ]

        super.setUp()
    }

    private func showRecentlyClosedTabs() {
        if !app.buttons["Add Tab"].exists {
            goToTabTray()
        }

        app.buttons["Add Tab"].press(forDuration: 1)
    }

    func testRecentlyClosedOptionAvailable() {
        // Now go back to default website close it and check whether the option is enabled
        openURL()
        waitUntilPageLoad()
        closeAllTabs(createNewTab: false)

        goToRecentlyClosedPage()

        // The Closed Tabs list should contain the info of the website just closed
        waitForExistence(app.scrollViews["recentlyClosedPanel"])
        waitForExistence(app.buttons["Example Domain"])
        app.buttons["History"].tap()
        app.buttons["Done"].firstMatch.tap()

        // This option should be enabled on private mode too
        setIncognitoMode(enabled: true)

        goToRecentlyClosedPage()
        waitForExistence(app.scrollViews["recentlyClosedPanel"])
    }

    func testClearRecentlyClosedHistory() {
        // Open the default website
        openURL()
        waitUntilPageLoad()
        closeAllTabs(createNewTab: false)

        goToRecentlyClosedPage()

        // Once the website is visited and closed it will appear in Recently Closed Tabs list
        waitForExistence(app.scrollViews["recentlyClosedPanel"])
        waitForExistence(app.buttons["Example Domain"])
        app.buttons["History"].tap()
        app.buttons["Done"].firstMatch.tap()

        clearPrivateData()
        goToHistory()

        // Check history/recently closed items are cleared
        waitForExistence(app.staticTexts["History List Empty"])
    }

    func testRecentlyClosedMenuAvailable() {
        openURL()
        waitUntilPageLoad()
        closeAllTabs(createNewTab: false)

        showRecentlyClosedTabs()
        XCTAssertTrue(app.buttons["Example Domain"].exists)
    }

    // MARK: - Open in New Tab
    func testOpenInNewTabRecentlyClosedItemFromMenu() {
        // test the recently closed tab menu
        openURL()
        waitUntilPageLoad()
        closeAllTabs(createNewTab: false)

        showRecentlyClosedTabs()
        app.buttons["Example Domain"].tap()

        XCTAssertEqual(getNumberOfTabs(openTabTray: false), 1)
    }

    func testOpenInNewTabRecentlyClosedItem() {
        // Test the recently closed tab page
        openURL()
        waitUntilPageLoad()
        closeAllTabs(createNewTab: false)

        goToRecentlyClosedPage()

        waitForExistence(app.scrollViews["recentlyClosedPanel"])
        app.buttons["Example Domain"].press(forDuration: 1)
        app.buttons["Open in new tab"].tap()
        app.buttons["History"].tap()
        app.buttons["Done"].firstMatch.tap()

        XCTAssertEqual(getNumberOfTabs(openTabTray: false), 1)
    }

    func testOpenInNewIncognitoTabRecentlyClosedItem() {
        // Open the default website
        openURL()
        waitUntilPageLoad()
        closeAllTabs(createNewTab: false)

        goToRecentlyClosedPage()

        waitForExistence(app.scrollViews["recentlyClosedPanel"])
        app.buttons["Example Domain"].press(forDuration: 1)
        app.buttons["Open in new incognito tab"].tap()
        app.buttons["History"].tap()
        app.buttons["Done"].firstMatch.tap()

        setIncognitoMode(enabled: true, shouldOpenURL: false, closeTabTray: false)

        XCTAssertEqual(getNumberOfTabs(openTabTray: false), 1)
    }

    func testIncognitoClosedSiteDoesNotAppearOnRecentlyClosedMenu() {
        setIncognitoMode(enabled: true)

        // Open the default website
        openURL()
        waitUntilPageLoad()
        closeAllTabs()

        showRecentlyClosedTabs()
        XCTAssertFalse(app.buttons["Example Domain"].exists)
    }

    func testIncognitoClosedSiteDoesNotAppearOnRecentlyClosed() {
        clearPrivateData()

        setIncognitoMode(enabled: true)
        goToHistory()
        waitForExistence(app.staticTexts["History List Empty"])
    }
}
