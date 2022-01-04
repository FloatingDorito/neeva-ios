/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Combine
import Defaults
import Foundation
import Shared
<<<<<<< HEAD
import SwiftUI
import WalletConnectSwift
=======
import MozillaAppServices

struct FxALaunchParams {
    var query: [String: String]
}

// An enum to route to HomePanels
enum HomePanelPath: String {
    
    case topSites = "top-sites"
    case readingList = "reading-list"
    case history = "history"
    case downloads = "downloads"
    case newPrivateTab = "new-private-tab"
}

// An enum to route to a settings page.
// This could be extended to provide default values to pass to fxa
enum SettingsPage: String {
    case general = "general"
    case newtab = "newtab"
    case homepage = "homepage"
    case mailto = "mailto"
    case search = "search"
    case clearPrivateData = "clear-private-data"
    case fxa = "fxa"
    case theme = "theme"
}

enum DefaultBrowserPath: String {
    case systemSettings = "system-settings"
}

// Used by the App to navigate to different views.
// To open a URL use /open-url or to open a blank tab use /open-url with no params
enum DeepLink {
    case settings(SettingsPage)
    case homePanel(HomePanelPath)
    case defaultBrowser(DefaultBrowserPath)
    init?(urlString: String) {
        let paths = urlString.split(separator: "/")
        guard let component = paths[safe: 0], let componentPath = paths[safe: 1] else {
            return nil
        }
        if component == "settings", let link = SettingsPage(rawValue: String(componentPath)) {
            self = .settings(link)
        } else if component == "homepanel", let link = HomePanelPath(rawValue: String(componentPath)) {
            self = .homePanel(link)
        } else if component == "default-browser", let link = DefaultBrowserPath(rawValue: String(componentPath)) {
            self = .defaultBrowser(link)
        } else {
            return nil
        }
    }
}
>>>>>>> parent of 4e81b3f2d (Remove search engine switching, Neeva branding and Search Engine view modifications)

extension URLComponents {
    // Return the first query parameter that matches
    func valueForQuery(_ param: String) -> String? {
        return self.queryItems?.first { $0.name == param }?.value
    }
}

// The root navigation for the Router. Look at the tests to see a complete URL
enum NavigationPath {
    case url(webURL: URL?, isPrivate: Bool)
    case widgetUrl(webURL: URL?, uuid: String)
    case text(String)
    case closePrivateTabs
    case space(String, [String]?, Bool)
    case fastTap(String, Bool)
    case configNewsProvider(isPrivate: Bool)
    case walletConnect(wcURL: WCURL)

    init?(bvc: BrowserViewController, url: URL) {
        let urlString = url.absoluteString
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        guard
            let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes")
                as? [AnyObject],
            let urlSchemes = urlTypes.first?["CFBundleURLSchemes"] as? [String]
        else {
            // Something very strange has happened
            return nil
        }

        guard let scheme = components.scheme, urlSchemes.contains(scheme) else {
            return nil
        }

        if urlString.starts(with: "\(scheme)://open-url") {
            self = .openUrlFromComponents(components: components)
        } else if let widgetKitNavPath = NavigationPath.handleWidgetKitQuery(
            urlString: urlString, scheme: scheme, components: components)
        {
            self = widgetKitNavPath
        } else if urlString.starts(with: "\(scheme)://open-text") {
            let text = components.valueForQuery("text")
            self = .text(text ?? "")
        } else if urlString.starts(with: "http:") || urlString.starts(with: "https:") {
            // Use the last browsing mode the user was in
            let isPrivate = UserDefaults.standard.bool(forKey: "wasLastSessionPrivate")
            self = .url(
                webURL: NavigationPath.maybeRewriteURL(url, components) ?? url, isPrivate: isPrivate
            )
        } else if urlString.starts(with: "\(scheme)://space"),
            let spaceId = components.valueForQuery("id")
        {
            let isPrivate = UserDefaults.standard.bool(forKey: "wasLastSessionPrivate")
            var updatedItemIds: [String]?
            if let ids = components.valueForQuery("updatedItemIds") {
                updatedItemIds = ids.components(separatedBy: ",")
            }
            self = .space(spaceId, updatedItemIds, isPrivate)
        } else if urlString.starts(with: "\(scheme)://fast-tap"),
            let query =
                components.valueForQuery("query")?.replacingOccurrences(of: "+", with: " ")
        {
            self = .fastTap(query, components.valueForQuery("no-delay") != nil)
        } else if urlString.starts(with: "\(scheme)://configure-news-provider") {
            let isPrivate = UserDefaults.standard.bool(forKey: "wasLastSessionPrivate")
            self = .configNewsProvider(isPrivate: isPrivate)
        } else if urlString.starts(with: "\(scheme)://wc?uri="),
            let wcURL = WCURL(
                urlString.dropFirst("\(scheme)://wc?uri=".count).removingPercentEncoding ?? "")
        {
            self = .walletConnect(wcURL: wcURL)
        } else {
            return nil
        }
    }

    static func handle(nav: NavigationPath, with bvc: BrowserViewController) {
        switch nav {
        case .url(let url, let isPrivate):
            NavigationPath.handleURL(url: url, isPrivate: isPrivate, with: bvc)
        case .text(let text):
            NavigationPath.handleText(text: text, with: bvc)
        case .closePrivateTabs:
            NavigationPath.handleClosePrivateTabs(with: bvc)
        case .widgetUrl(let webURL, let uuid):
            NavigationPath.handleWidgetURL(url: webURL, uuid: uuid, with: bvc)
        case .space(let spaceId, let updatedItemIds, let isPrivate):
            NavigationPath.handleSpace(
                spaceId: spaceId, updatedItemIds: updatedItemIds, isPrivate: isPrivate, with: bvc)
        case .fastTap(let query, let noDelay):
            NavigationPath.handleFastTap(query: query, with: bvc, noDelay: noDelay)
        case .configNewsProvider(let isPrivate):
            NavigationPath.handleURL(
                url: NeevaConstants.configureNewsProviderURL, isPrivate: isPrivate, with: bvc)
        case .walletConnect(let wcURL):
            bvc.connectWallet(to: wcURL)
        }
    }

    static func navigationPath(from url: URL, with bvc: BrowserViewController) -> NavigationPath? {
        guard url.absoluteString.hasPrefix(NeevaConstants.appDeepLinkURL.absoluteString),
            let deepLink = URL(
                string: "neeva://"
                    + url.absoluteString.dropFirst(
                        NeevaConstants.appDeepLinkURL.absoluteString.count))
        else {
            return nil
        }

        return NavigationPath(bvc: bvc, url: deepLink)
    }

    private static func handleWidgetKitQuery(
        urlString: String, scheme: String, components: URLComponents
    ) -> NavigationPath? {
        if urlString.starts(with: "\(scheme)://widget-medium-topsites-open-url") {
            // Widget Top sites - open url
            return .openUrlFromComponents(components: components)
        } else if urlString.starts(with: "\(scheme)://widget-small-quicklink-open-url") {
            // Widget Quick links - small - open url private or regular
            return .openUrlFromComponents(components: components)
        } else if urlString.starts(with: "\(scheme)://widget-medium-quicklink-open-url") {
            // Widget Quick Actions - medium - open url private or regular
            return .openUrlFromComponents(components: components)
        } else if urlString.starts(with: "\(scheme)://widget-small-quicklink-open-copied")
            || urlString.starts(with: "\(scheme)://widget-medium-quicklink-open-copied")
        {
            // Widget Quick links - medium - open copied url
            return .openCopiedUrl()
        } else if urlString.starts(with: "\(scheme)://widget-small-quicklink-close-private-tabs")
            || urlString.starts(with: "\(scheme)://widget-medium-quicklink-close-private-tabs")
        {
            // Widget Quick links - medium - close private tabs
            return .closePrivateTabs
        }

        return nil
    }

    private static func openUrlFromComponents(components: URLComponents)
        -> NavigationPath
    {
        let url = components.valueForQuery("url")?.asURL
        // Unless the `open-url` URL specifies a `private` parameter,
        // use the last browsing mode the user was in.
        let isPrivate =
            Bool(components.valueForQuery("private") ?? "")
            ?? UserDefaults.standard.bool(forKey: "wasLastSessionPrivate")
        return .url(webURL: url, isPrivate: isPrivate)
    }

    private static func openCopiedUrl() -> NavigationPath {
        if !UIPasteboard.general.hasURLs {
            let searchText = UIPasteboard.general.string ?? ""
            return .text(searchText)
        }
        let url = UIPasteboard.general.url
        let isPrivate = UserDefaults.standard.bool(forKey: "wasLastSessionPrivate")
        return .url(webURL: url, isPrivate: isPrivate)
    }

    private static func handleClosePrivateTabs(with bvc: BrowserViewController) {
        bvc.tabManager.removeTabs(bvc.tabManager.privateTabs, updatingSelectedTab: true)
        guard let tab = mostRecentTab(inTabs: bvc.tabManager.normalTabs) else {
            bvc.tabManager.selectTab(bvc.tabManager.addTab())
            return
        }
        bvc.tabManager.selectTab(tab)
    }

    private static func handleURL(url: URL?, isPrivate: Bool, with bvc: BrowserViewController) {
        if let newURL = url {
            bvc.switchToTabForURLOrOpen(newURL, isPrivate: isPrivate)
        } else {
            bvc.openBlankNewTab(focusLocationField: true, isPrivate: isPrivate)
        }
    }

    private static func handleWidgetURL(url: URL?, uuid: String, with bvc: BrowserViewController) {
        if let newURL = url {
            bvc.switchToTabForWidgetURLOrOpen(newURL, uuid: uuid, isPrivate: false)
        } else {
            bvc.openBlankNewTab(focusLocationField: true, isPrivate: false)
        }
    }

    private static func handleText(text: String, with bvc: BrowserViewController) {
        bvc.openBlankNewTab(focusLocationField: false)
        bvc.urlBar(didSubmitText: text)
    }

    private static func handleSpace(
        spaceId: String, updatedItemIds: [String]?, isPrivate: Bool, with bvc: BrowserViewController
    ) {
        // navigate to SpaceId
        let gridModel = bvc.gridModel
        if let updatedItemIDs = updatedItemIds, !updatedItemIDs.isEmpty {
            gridModel.spaceCardModel.updatedItemIDs = updatedItemIDs
        }
        gridModel.openSpace(spaceId: spaceId, bvc: bvc, isPrivate: isPrivate, completion: {})
    }

    private static func handleFastTap(query: String, with bvc: BrowserViewController, noDelay: Bool)
    {
        DispatchQueue.main.asyncAfter(deadline: .now() + (noDelay ? 0 : 1.5)) {
            bvc.openLazyTab()
            bvc.searchQueryModel.value = query
        }
    }

    public static func maybeRewriteURL(_ url: URL, _ components: URLComponents) -> URL? {
        // Intercept and rewrite search queries incoming from e.g. SpotLight.
        //
        // Example of what components looks like:
        //    - scheme : "https"
        //    - host : "www.google.com"
        //    - path : "/search"
        //    ▿ queryItems : 5 elements
        //      ▿ 0 : q=foo+bar
        //        - name : "q"
        //        ▿ value : Optional<String>
        //          - some : "foo+bar"
        //      ▿ 1 : ie=UTF-8
        //        - name : "ie"
        //        ▿ value : Optional<String>
        //          - some : "UTF-8"
        //      ▿ 2 : oe=UTF-8
        //        - name : "oe"
        //        ▿ value : Optional<String>
        //          - some : "UTF-8"
        //      ▿ 3 : hl=en
        //        - name : "hl"
        //        ▿ value : Optional<String>
        //          - some : "en"
        //      ▿ 4 : client=safari
        //        - name : "client"
        //        ▿ value : Optional<String>
        //          - some : "safari"
        //

        // search query value
        var value: String?

<<<<<<< HEAD
        if let host = components.host, let queryItems = components.percentEncodedQueryItems {
            switch host {
            case "www.google.com", "www.bing.com", "www.ecosia.org", "search.yahoo.com":
                // yahoo uses p for the search query name instead of q
                let queryName = host == "search.yahoo.com" ? "p" : "q"
                if components.path == "/search" {
                    value = queryItems.first(where: { $0.name == queryName })?.value
                }
            case "duckduckgo.com":
                // duckduckgo doesn't include the /search path
                value = queryItems.first(where: { $0.name == "q" })?.value
            case "yandex.com":
                if components.path == "/search/touch/" {
                    value = queryItems.first(where: { $0.name == "text" })?.value
                }
            case "www.baidu.com", "www.so.com":
                let queryName = host == "www.baidu.com" ? "oq" : "src"
                if components.path == "/s" {
                    value = queryItems.first(where: { $0.name == queryName })?.value
                }
            case "www.sogou.com":
                if components.path == "/web" {
                    value = queryItems.first(where: { $0.name == "query" })?.value
                }
            default:
                return nil
            }
=======
        switch settings {
        case .general:
            break // Intentional NOOP; Already displaying the general settings VC
        case .newtab:
            let viewController = NewTabContentSettingsViewController(prefs: baseSettingsVC.profile.prefs)
            viewController.profile = profile
            controller.pushViewController(viewController, animated: true)
        case .homepage:
            let viewController = HomePageSettingViewController(prefs: baseSettingsVC.profile.prefs)
            viewController.profile = profile
            controller.pushViewController(viewController, animated: true)
        case .mailto:
            let viewController = OpenWithSettingsViewController(prefs: profile.prefs)
            controller.pushViewController(viewController, animated: true)
        case .search:
            let viewController = SearchSettingsTableViewController()
            viewController.model = profile.searchEngines
            viewController.profile = profile
            controller.pushViewController(viewController, animated: true)
        case .clearPrivateData:
            let viewController = ClearPrivateDataTableViewController()
            viewController.profile = profile
            viewController.tabManager = tabManager
            controller.pushViewController(viewController, animated: true)
        case .fxa:
            let viewController = bvc.getSignInOrFxASettingsVC(flowType: .emailLoginFlow, referringPage: .settings)
            controller.pushViewController(viewController, animated: true)
        case .theme:
            controller.pushViewController(ThemeSettingsController(), animated: true)
>>>>>>> parent of 4e81b3f2d (Remove search engine switching, Neeva branding and Search Engine view modifications)
        }

        if let value = value?.replacingOccurrences(of: "+", with: " ").removingPercentEncoding,
            let newURL = neevaSearchEngine.searchURLForQuery(value)
        {
            return newURL
        } else {
            return nil
        }
    }
}

extension NavigationPath: Equatable {}

func == (lhs: NavigationPath, rhs: NavigationPath) -> Bool {
    switch (lhs, rhs) {
    case let (.url(lhsURL, lhsPrivate), .url(rhsURL, rhsPrivate)):
        return lhsURL == rhsURL && lhsPrivate == rhsPrivate
    default:
        return false
    }
}
