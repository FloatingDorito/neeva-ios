/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest

let webpage = [
    "url": "www.mozilla.org", "label": "Internet for people, not profit — Mozilla",
    "value": "mozilla.org",
]
let oldHistoryEntries: [String] = [
    "Internet for people, not profit — Mozilla", "Twitter", "Home - YouTube",
]
// This is part of the info the user will see in recent closed tabs once the default visited website (https://www.mozilla.org/en-US/book/) is closed
let closedWebPageLabel = "localhost:\(serverPort)/test-fixture/test-mozilla-book.html"

class HistoryTests: BaseTestCase {
    let testWithDB = [
        "testOpenHistoryFromBrowserContextMenuOptions", "testClearHistoryFromSettings",
        "testClearRecentHistory", "testSearchHistory", "testDeleteItem", "testOpenItemOnTap", "testOpenInNewTab", "testOpenInNewIncognitoTab"
    ]

    // This DDBB contains those 4 websites listed in the name
    let historyDB = "browserYoutubeTwitterMozillaExample.db"
    let clearRecentHistoryOptions = ["Last Hour", "Today", "Today & Yesterday", "Everything"]
    
    override func setUp() {
        if testWithDB.contains(testName) {
            // for the current test name, add the db fixture used
            launchArguments = [
                LaunchArguments.SkipIntro, LaunchArguments.SkipWhatsNew,
                LaunchArguments.SkipETPCoverSheet, LaunchArguments.LoadDatabasePrefix + historyDB,
            ]
        }
        launchArguments.append(LaunchArguments.DontAddTabOnLaunch)
        super.setUp()
    }

    private func clearWebsiteData() {
        goToSettings()

        waitForExistence(app.cells["Clear Browsing Data"])
        app.cells["Clear Browsing Data"].tap()
        app.cells["Clear Selected Data on This Device"].tap()

        waitForExistence(app.buttons["Clear Data"])
        app.buttons["Clear Data"].tap()
        waitForNoExistence(app.buttons["Clear Data"])

        app.buttons["Settings"].tap()
        app.navigationBars["Settings"].buttons["Done"].tap()
    }
    
    // Private function created to select desired option from the "Clear Recent History" list
    // We used this aproch to avoid code duplication
    private func tapOnClearRecentHistoryOption(optionSelected: String) {
        app.buttons[optionSelected].tap()
    }

    private func navigateToExample() {
        openURL("example.com")
        waitUntilPageLoad()
    }

    // MARK: - Clear Data
    func testClearHistoryFromSettings() {
        // Go to Clear Data
        clearWebsiteData()

        // Back on History panel view check that there is not any item
        goToHistory()
        XCTAssertFalse(app.tables.cells.staticTexts[webpage["label"]!].exists)
    }

    func testClearPrivateDataButtonDisabled() {
        // Clear private data from settings and confirm
        clearPrivateData()

        // Wait for OK pop-up to disappear after confirming
        waitForNoExistence(app.alerts.buttons["Clear Data"], timeoutValue: 5)

        // Assert that the button has been replaced with a success message
        XCTAssertFalse(app.tables.cells["Clear Selected Data on This Device"].exists)
    }

    // MARK: - Clear History
    func testAllClearOptionsArePresent() {
        navigateToExample()
        goToHistory()

        waitForExistence(app.buttons["Clear Recent History"])
        app.buttons["Clear Recent History"].tap()

        for option in clearRecentHistoryOptions {
            XCTAssertTrue(app.sheets.buttons[option].exists)
        }
    }

    func testClearRecentHistory() {
        func reset() {
            waitForExistence(app.buttons["Done"])
            app.buttons["Done"].firstMatch.tap()
            navigateToExample()

            goToHistory()
            waitForExistence(app.staticTexts["Example Domain"])
            waitForExistence(app.buttons["Clear Recent History"])
            app.buttons["Clear Recent History"].tap()
        }
        
        goToHistory()
        waitForExistence(app.buttons["Clear Recent History"])
        app.buttons["Clear Recent History"].tap()

        // Last hour.
        // No data will be removed after Action.ClearRecentHistory since there is no recent history created.
        tapOnClearRecentHistoryOption(optionSelected: "Last Hour")
        for entry in oldHistoryEntries {
            XCTAssertTrue(app.buttons[entry].exists)
        }

        reset()
        
        // Today.
        // Recent data will be removed after calling tapOnClearRecentHistoryOption(optionSelected: "Today").
        // Older data will not be removed
        tapOnClearRecentHistoryOption(optionSelected: "Today")
        for entry in oldHistoryEntries {
            XCTAssertTrue(app.buttons[entry].exists)
        }
        XCTAssertFalse(app.buttons["example.com"].exists)

        reset()
        
        // Today & Yesterday.
        // Tapping "Today and Yesterday" will remove recent data (from yesterday and today).
        // Older data will not be removed
        tapOnClearRecentHistoryOption(optionSelected: "Today & Yesterday")
        for entry in oldHistoryEntries {
            XCTAssertTrue(app.buttons[entry].exists)
        }
        XCTAssertFalse(app.buttons["example.com"].exists)

        reset()
        
        // Everything.
        // Tapping everything removes both current data and older data.
        tapOnClearRecentHistoryOption(optionSelected: "Everything")
        for entry in oldHistoryEntries {
            waitForNoExistence(app.buttons[entry], timeoutValue: 10)
            XCTAssertFalse(app.buttons[entry].exists, "History not removed")
        }
        XCTAssertFalse(app.tables.cells.staticTexts["example.com"].exists)
        waitForExistence(app.staticTexts["History List Empty"])
    }
    
    // MARK: - Delete
    func testDeleteItem() {
        goToHistory()
        
        waitForExistence(app.buttons["Twitter"])
        app.buttons["Twitter"].press(forDuration: 1)
        app.buttons["Delete"].tap()
        
        waitForNoExistence(app.buttons["Twitter"])
    }
    
    // MARK: - Empty History
    func testEmptyHistoryListFirstTime() {
        // Go to History List from Top Sites and check it is empty
        goToHistory()
        waitForExistence(app.staticTexts["History List Empty"])
    }
    
    // MARK: - Open
    func testOpenItemOnTap() {
        openURL("example.com")
        
        goToHistory()
        waitForExistence(app.buttons["Twitter"])
        app.buttons["Twitter"].tap()
        
        XCTAssertEqual(getNumberOfTabs(), 2)
    }
    
    // MARK: - Open in New Tab
    func testOpenInNewTab() {
        openURL("example.com")
        goToHistory()
        
        waitForExistence(app.buttons["Twitter"])
        app.buttons["Twitter"].press(forDuration: 1)
        app.buttons["Open in new tab"].tap()
        
        waitForExistence(app.buttons["Switch"])
        app.buttons["Done"].tap()
        
        goToTabTray()
        XCTAssertEqual(getNumberOfTabs(openTabTray: false), 2)
    }
    
    func testOpenInNewIncognitoTab() {
        openURL("example.com")
        goToHistory()
        
        waitForExistence(app.buttons["Twitter"])
        app.buttons["Twitter"].press(forDuration: 1)
        app.buttons["Open in new incognito tab"].tap()
        
        waitForExistence(app.buttons["Switch"])
        app.buttons["Done"].tap()
        
        setIncognitoMode(enabled: true, shouldOpenURL: false, closeTabTray: false)
        XCTAssertEqual(getNumberOfTabs(openTabTray: false), 1)
    }

    // MARK: - Search
    func testSearchHistory() {
        goToHistory()

        // Make sure sites are visible before search.
        waitForExistence(app.staticTexts["Example Domain"])
        waitForExistence(app.buttons["Twitter"])

        // Select TextField.
        waitForHittable(app.textFields["History Search TextField"])
        app.textFields["History Search TextField"].tap(force: true)

        // Perform search and verify only the correct site is shown.
        app.textFields["History Search TextField"].typeText("example.com")
        waitForNoExistence(app.buttons["Twitter"])
        waitForExistence(app.staticTexts["Example Domain"])
    }
}
