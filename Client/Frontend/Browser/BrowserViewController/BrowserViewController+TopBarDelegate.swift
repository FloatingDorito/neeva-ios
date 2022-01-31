// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Defaults
import SFSafeSymbols
import Shared
import Storage

extension BrowserViewController: TopBarDelegate {
    func urlBarDidPressReload() {
        // log tap reload
        ClientLogger.shared.logCounter(
            .TapReload, attributes: EnvironmentHelper.shared.getAttributes())

        tabManager.selectedTab?.reload()
    }

    func urlBarDidPressStop() {
        tabManager.selectedTab?.stop()
    }

    func urlBarReloadMenu() -> UIMenu? {
        guard
            let tab = tabManager.selectedTab,
            tab.webView?.url != nil,
            (tab.getContentScript(name: ReaderMode.name()) as? ReaderMode)?.state != .active
        else { return nil }

        let toggleActionTitle: String
        let iconName: SFSymbol

        let willSwitchToMobile =
            UserAgent.isDesktop(ua: UserAgent.getUserAgent())
            ? !tab.changedUserAgent : tab.changedUserAgent
        if willSwitchToMobile {
            toggleActionTitle = Strings.AppMenuViewMobileSiteTitleString
            iconName = UIConstants.hasHomeButton ? .iphoneHomebutton : .iphone
        } else {
            toggleActionTitle = Strings.AppMenuViewDesktopSiteTitleString
            iconName = .laptopcomputer
        }

        Haptics.longPress()

        return UIMenu(
            children: [
                UIAction(title: toggleActionTitle, image: UIImage(systemSymbol: iconName)) { _ in
                    if let url = tab.url {
                        tab.toggleChangeUserAgent()
                        Tab.ChangeUserAgent.updateDomainList(
                            forUrl: url,
                            isChangedUA: tab.changedUserAgent,
                            isPrivate: self.tabManager.isIncognito
                        )
                    }
                }
            ]
        )
    }

    func urlBar(didSubmitText text: String, isSearchQuerySuggestion: Bool = false) {
        // When user enter text in the url bar, assume user figured out
        // how to search from url bar, so auto dismiss the search input tour prompt
        Defaults[.searchInputPromptDismissed] = true

        let currentTab = tabManager.selectedTab

        if let fixupURL = URIFixup.getURL(text), !isSearchQuerySuggestion {
            // The user entered a URL, so use it.
            finishEditingAndSubmit(fixupURL, visitType: VisitType.typed, forTab: currentTab)
            return
        }

        // User is editing the current query, should preserve the parameters from their original query
        if let queryItems = searchQueryModel.queryItems,
            let url = SearchEngine.current.searchURLFrom(searchQuery: text, queryItems: queryItems)
        {
            finishEditingAndSubmit(url, visitType: VisitType.typed, forTab: currentTab)

            searchQueryModel.queryItems = nil

            return
        }

        // We couldn't build a URL, so check for a matching search keyword.
        let trimmedText = text.trimmingCharacters(in: .whitespaces)
        guard trimmedText.firstIndex(of: " ") != nil else {
            submitSearchText(text, forTab: currentTab)
            return
        }

        self.submitSearchText(text, forTab: currentTab)
    }

    fileprivate func submitSearchText(_ text: String, forTab tab: Tab?) {
        if let searchURL = SearchEngine.current.searchURLForQuery(text) {
            // We couldn't find a matching search keyword, so do a search query.
            finishEditingAndSubmit(searchURL, visitType: VisitType.typed, forTab: tab)
        } else {
            // We still don't have a valid URL, so something is broken. Give up.
            print("Error handling URL entry: \"\(text)\".")
            assertionFailure("Couldn't generate search URL: \(text)")
        }
    }
}
