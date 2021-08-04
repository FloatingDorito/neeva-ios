/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import WebKit

class HistoryTests: KIFTestCase {
    fileprivate var webRoot: String!

    override func setUp() {
        super.setUp()
        webRoot = SimplePageServer.start()
        BrowserUtils.dismissFirstRunUI(tester())
    }

    override func tearDown() {
        BrowserUtils.resetToAboutHomeKIF(tester())
    }

    func addHistoryItemPage(_ pageNo: Int) -> String {
        // Load a page
        let url = "\(webRoot!)/numberedPage.html?page=\(pageNo)"

        BrowserUtils.enterUrlAddressBar(tester(), typeUrl: url)
        tester().waitForWebViewElementWithAccessibilityLabel("Page \(pageNo)")
        return url
    }

    func addHistoryItems(_ noOfItemsToAdd: Int) -> [String] {
        var urls = [String]()
        for index in 1...noOfItemsToAdd {
            urls.append(addHistoryItemPage(index))
        }
        return urls
    }

    /// Tests for listed history visits
    func testAddHistoryUI() {
        _ = addHistoryItems(2)

        // Check that both appear in the history home panel
        BrowserUtils.openNeevaMenu(tester())
        tester().tapView(withAccessibilityLabel: "History")

        // Wait until the dialog shows up
        tester().waitForAnimationsToFinish()
        tester().waitForView(withAccessibilityLabel: "Page 2")

        tester().waitForView(withAccessibilityLabel: "Page 1")
        tester().waitForView(withAccessibilityLabel: "\(webRoot!)/numberedPage.html?page=2")
        tester().waitForView(withAccessibilityLabel: "\(webRoot!)/numberedPage.html?page=1")

        // Close History (and so Library) panel
        BrowserUtils.closeHistorySheet(tester())
    }

    // Could be removed since tested on XCUITets -> AP VERIFY OR ADD
    /*
    func testDeleteHistoryItemFromListWith2Items() {
        // add 2 history items
        let urls = addHistoryItems(2)

        // Check that both appear in the history home panel
        BrowserUtils.openLibraryMenu(tester())
        tester().waitForAnimationsToFinish()

        EarlGrey.selectElement(with: grey_accessibilityLabel(urls[0]))
            .perform(grey_longPress())

        tester().tapView(withAccessibilityLabel: "Delete from History")

        // The second history entry still exists
        EarlGrey.selectElement(with: grey_accessibilityLabel(urls[1]))
            .inRoot(grey_kindOfClass(NSClassFromString("UITableViewCellContentView")!))
            .assert(grey_notNil())

        // check page 1 does not exist
        let historyRemoved = GREYCondition(name: "Check entry is removed", block: {
            var errorOrNil: NSError?
            let matcher = grey_allOf([grey_accessibilityLabel(urls[0]),
                                              grey_sufficientlyVisible()])
            EarlGrey.selectElement(with: matcher).assert(grey_notNil(), error: &errorOrNil)
            let success = errorOrNil != nil
            return success
        }).wait(withTimeout: 5)
        GREYAssertTrue(historyRemoved, reason: "Failed to remove history")

        // Close History (and so Library) panel
        BrowserUtils.closeLibraryMenu(tester())
    }*/

    func testDeleteHistoryItemFromListWithMoreThan100Items() {
        for pageNo in 1...102 {
            BrowserUtils.addHistoryEntry(
                "Page \(pageNo)", url: URL(string: "\(webRoot!)/numberedPage.html?page=\(pageNo)")!)
        }
        tester().wait(forTimeInterval: 2)
        let oldestUrl = "\(webRoot!)/numberedPage.html?page=\(101)"
        tester().waitForAnimationsToFinish()
        BrowserUtils.openNeevaMenu(tester())
        tester().waitForAnimationsToFinish(withTimeout: 10)
        tester().waitForView(withAccessibilityLabel: "History")
        tester().tapView(withAccessibilityLabel: "History")
        tester().waitForView(withAccessibilityLabel: "Page 102")

        let firstIndexPath = IndexPath(row: 0, section: 1)
        let row = tester().waitForCell(
            at: firstIndexPath, inTableViewWithAccessibilityIdentifier: "History List")
        tester().waitForAnimationsToFinish()
        tester().longPressView(
            withAccessibilityLabel: row?.accessibilityLabel, value: row?.accessibilityValue,
            duration: 1)

        // The history list still exists
        tester().waitForView(withAccessibilityIdentifier: "History List")
        tester().waitForView(withAccessibilityLabel: oldestUrl)

        // check that the deleted page does not exist
        tester().waitForAbsenceOfView(withAccessibilityLabel: row?.accessibilityLabel)

        // On iPad, there is no explicit "Cancel" button. Instead, we just have to
        // tap outside the bounds of the prompt. The "Done" button from the History
        // Panel provides a way to do that.
        if BrowserUtils.iPad() {
            tester().tapView(withAccessibilityLabel: "Done")
        } else {
            tester().tapView(withAccessibilityLabel: "Cancel")
        }

        // Close History (and so Library) panel
        BrowserUtils.closeHistorySheet(tester())
    }
}
