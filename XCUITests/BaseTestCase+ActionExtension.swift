// Copyright Neeva. All rights reserved.

import XCTest

extension BaseTestCase {
    /// Launches from tab page, or runs if already in tab tray.
    /// Switches between incognito modes by clicking incognito button
    func toggleIncognito() {
        if !app.buttons["Incognito Mode"].exists {
            goToTabTray()
        }

        app.buttons["Incognito Mode"].tap()

        if app.buttons["Done"].exists && app.buttons["Done"].isHittable {
            app.buttons["Done"].tap()
        }
    }

    /// Launches from tab page, holds reload button
    func requestDesktopSite() {
        app.buttons["Reload"].press(forDuration: 1)
        app.buttons["Request Desktop Site"].tap()
    }

    /// Launches from tab page, holds reload button
    func requestMobileSite() {
        app.buttons["Reload"].press(forDuration: 1)
        app.buttons["Request Mobile Site"].tap()
    }

    /// Launches from tab page, ends on tab page
    func clearPrivateData(fromTab: Bool = true) {
        if fromTab {
            goToClearData()
        }

        app.cells["Clear Selected Data on This Device"].tap()
        app.buttons["Clear Data"].tap()
        waitForNoExistence(app.buttons["Clear Data"])

        // close settings
        app.buttons["Settings"].tap()

        waitForExistence(app.buttons["Done"])
        app.buttons["Done"].tap()
    }
}
