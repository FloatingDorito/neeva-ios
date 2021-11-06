/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared
import Storage
import WebKit

// This cannot be easily imported into extension targets, so we break it out here.
extension SavedTab {
    convenience init(tab: Tab, isSelected: Bool, tabIndex: Int?) {
        assert(Thread.isMainThread)

        var sessionData = tab.sessionData
        if sessionData == nil {
            let currentItem: WKBackForwardListItem! = tab.webView?.backForwardList.currentItem

            // Freshly created web views won't have any history entries at all.
            // If we have no history, abort.
            if currentItem != nil {
                // The back & forward list keep track of the users history within the session
                let backList = tab.webView?.backForwardList.backList ?? []
                let forwardList = tab.webView?.backForwardList.forwardList ?? []
                let urls = (backList + [currentItem] + forwardList).map { $0.url }
                let currentPage = -forwardList.count
                sessionData = SessionData(
                    currentPage: currentPage, urls: urls,
                    lastUsedTime: tab.lastExecutedTime ?? Date.nowMilliseconds())
            }
        }

        self.init(
            screenshotUUID: tab.screenshotUUID, isSelected: isSelected,
            title: tab.title ?? tab.lastTitle, isPrivate: tab.isIncognito,
            faviconURL: tab.displayFavicon?.url,
            url: tab.url, sessionData: sessionData,
            uuid: tab.tabUUID, rootUUID: tab.rootUUID, parentUUID: tab.parentUUID ?? "",
            tabIndex: tabIndex, parentSpaceID: tab.parentSpaceID ?? "")
    }

    func configureSavedTabUsing(_ tab: Tab, imageStore: DiskImageStore? = nil) -> Tab {
        // Since this is a restored tab, reset the URL to be loaded as that will be handled by the SessionRestoreHandler
        tab.setURL(nil)

        if let faviconURL = faviconURL {
            let icon = Favicon(url: faviconURL, date: Date())
            icon.width = 1
            tab.favicon = icon
        }

        if let screenshotUUID = screenshotUUID,
            let imageStore = imageStore
        {
            tab.screenshotUUID = screenshotUUID
            imageStore.get(screenshotUUID.uuidString) >>== { screenshot in
                if tab.screenshotUUID == screenshotUUID {
                    tab.setScreenshot(screenshot, revUUID: false)
                }
            }
        }

        tab.sessionData = sessionData
        tab.lastTitle = title
        tab.tabUUID = UUID ?? ""
        tab.rootUUID = rootUUID ?? ""
        tab.parentSpaceID = parentSpaceID ?? ""

        return tab
    }
}
