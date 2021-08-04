/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest

let serverPort = Int.random(in: 1025..<65000)

func path(forTestPage page: String) -> String {
    return "http://localhost:\(serverPort)/test-fixture/\(page)"
}

class BaseTestCase: XCTestCase {
    let app = XCUIApplication()

    // leave empty for non-specific tests
    var specificForPlatform: UIUserInterfaceIdiom?

    // These are used during setUp(). Change them prior to setUp() for the app to launch with different args,
    // or, use restart() to re-launch with custom args.
    var launchArguments = [
        LaunchArguments.ClearProfile, LaunchArguments.SkipIntro, LaunchArguments.SkipWhatsNew,
        LaunchArguments.SkipETPCoverSheet, LaunchArguments.DeviceName,
        "\(LaunchArguments.ServerPort)\(serverPort)",
    ]

    func setUpApp() {
        if !launchArguments.contains("FIREFOX_PERFORMANCE_TEST") {
            app.launchArguments = [LaunchArguments.Test] + launchArguments
        } else {
            app.launchArguments = [LaunchArguments.PerformanceTest] + launchArguments
        }
        app.launch()
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        setUpApp()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    var skipPlatform: Bool {
        guard let platform = specificForPlatform else { return false }
        return UIDevice.current.userInterfaceIdiom != platform
    }

    func restart(_ app: XCUIApplication, args: [String] = []) {
        XCUIDevice.shared.press(.home)
        var launchArguments = [LaunchArguments.Test]
        args.forEach { arg in
            launchArguments.append(arg)
        }
        app.launchArguments = launchArguments
        app.activate()
    }

    //If it is a first run, first run window should be gone
    func dismissFirstRunUI() {
        let firstRunUI = XCUIApplication().scrollViews["IntroViewController.scrollView"]

        if firstRunUI.exists {
            firstRunUI.swipeLeft()
            XCUIApplication().buttons["Start Browsing"].tap()
        }
    }

    func waitForExistence(
        _ element: XCUIElement, timeout: TimeInterval = 5.0, file: String = #file,
        line: UInt = #line
    ) {
        waitFor(element, with: "exists == true", timeout: timeout, file: file, line: line)
    }

    func waitForNoExistence(
        _ element: XCUIElement, timeoutValue: TimeInterval = 5.0, file: String = #file,
        line: UInt = #line
    ) {
        waitFor(element, with: "exists != true", timeout: timeoutValue, file: file, line: line)
    }

    func waitForValueContains(
        _ element: XCUIElement, value: String, timeout: TimeInterval = 5.0, file: String = #file,
        line: UInt = #line
    ) {
        waitFor(
            element, with: "value CONTAINS '\(value)'", timeout: timeout, file: file, line: line)
    }

    private func waitFor(
        _ element: XCUIElement, with predicateString: String, description: String? = nil,
        timeout: TimeInterval = 5.0, file: String, line: UInt
    ) {
        let predicate = NSPredicate(format: predicateString)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        if result != .completed {
            let message =
                description ?? "Expect predicate \(predicateString) for \(element.description)"
            self.record(XCTIssue(type: .assertionFailure, compactDescription: message))
        }
    }

    func iPad() -> Bool {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return true
        }
        return false
    }

    func waitUntilPageLoad() {
        let app = XCUIApplication()
        let progressIndicator = app.progressIndicators.element(boundBy: 0)

        waitForNoExistence(progressIndicator, timeoutValue: 20.0)
    }

    func waitForTabsButton() {
        // iPhone sim tabs button is called differently when in portrait or landscape
        if XCUIDevice.shared.orientation == UIDeviceOrientation.landscapeLeft {
            waitForExistence(app.buttons["URLBarView.tabsButton"], timeout: 15)
        } else {
            waitForExistence(app.buttons["Show Tabs"], timeout: 15)
        }
    }

    public func openURL(_ url: String = "example.com") {
        UIPasteboard.general.string = url

        if app.buttons["Cancel"].exists {
            app.textFields["address"].press(forDuration: 2)
        } else {
            app.buttons["Address Bar"].press(forDuration: 2)
        }

        waitForExistence(app.menuItems["Paste & Go"])
        app.menuItems["Paste & Go"].tap()

        waitForNoExistence(app.staticTexts["Neeva pasted from XCUITests-Runner"])

        waitUntilPageLoad()
        waitForTabsButton()
    }

    public func openURLInNewTab(_ url: String = "example.com") {
        newTab()
        openURL(url)
    }

    public func newTab() {
        app.buttons["Show Tabs"].press(forDuration: 2)

        if app.buttons["New Tab"].exists {
            app.buttons["New Tab"].tap()
        } else {
            app.buttons["New Incognito Tab"].tap()
        }
    }

    public func closeAllTabs() {
        app.buttons["Show Tabs"].press(forDuration: 1)

        let closeAllTabButton = app.buttons["Close All Tabs"]
        if closeAllTabButton.exists {
            closeAllTabButton.tap()

            waitForExistence(app.buttons["Confirm Close All Tabs"], timeout: 3)
            app.buttons["Confirm Close All Tabs"].tap()
        } else {
            app.buttons["Close Tab"].tap()
        }
    }

    /// Returns the number of open tabs. Must be called while the tab switcher is active.
    public func getTabs() -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label ENDSWITH ', Tab'"))
    }

    public func getNumberOfTabs() -> Int {
        goToTabTray()
        return getTabs().count
    }
}

class IpadOnlyTestCase: BaseTestCase {
    override func setUp() {
        specificForPlatform = .pad
        if iPad() {
            super.setUp()
        }
    }
}

class IphoneOnlyTestCase: BaseTestCase {
    override func setUp() {
        specificForPlatform = .phone
        if !iPad() {
            super.setUp()
        }
    }
}

extension BaseTestCase {
    func tabTrayButton(forApp app: XCUIApplication) -> XCUIElement {
        return app.buttons["Show Tabs"]
    }
}

extension XCUIElement {
    func tap(force: Bool) {
        // There appears to be a bug with tapping elements sometimes, despite them being on-screen and tappable, due to hittable being false.
        // See: http://stackoverflow.com/a/33534187/1248491
        if isHittable {
            tap()
        } else if force {
            coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
