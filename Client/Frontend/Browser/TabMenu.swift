// Copyright Neeva. All rights reserved.

import Shared
import Storage
import UIKit

class TabMenu {
    var tabManager: TabManager
    var zeroQueryViewController: ZeroQueryViewController?
    var alertPresentViewController: UIViewController?

    var tabsClosed: ((Bool) -> Void)?

    // MARK: Close All Tabs
    func showConfirmCloseAllTabs(numberOfTabs: Int) {
        let isPrivate = tabManager.selectedTab?.isPrivate ?? false
        guard let alertPresentViewController = alertPresentViewController else {
            return
        }

        let actionSheet = UIAlertController(
            title: nil,
            message: "Are you sure you want to close all open \(isPrivate ? "private " : "")tabs?",
            preferredStyle: .actionSheet)

        let closeAction = UIAlertAction(
            title:
                "Close \(numberOfTabs) \(isPrivate ? "Private " : "")\(numberOfTabs > 1 ? "Tabs" : "Tab")",
            style: .destructive
        ) { [self] _ in
            if isPrivate {
                _ = tabManager.switchPrivacyMode()

                // wait for tabManager to switch to normal mode before closing private tabs
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    tabManager.removeTabsAndAddNormalTab(tabManager.privateTabs, showToast: false)
                }
            } else {
                tabManager.removeTabsAndAddNormalTab(tabManager.normalTabs, showToast: false)
            }

            if let tabsClosed = tabsClosed {
                tabsClosed(isPrivate)
            }
        }
        closeAction.accessibilityLabel = "Confirm Close All Tabs"

        if let popoverPresentationController = actionSheet.popoverPresentationController {
            popoverPresentationController.sourceView = alertPresentViewController.view
            popoverPresentationController.sourceRect = CGRect(
                x: alertPresentViewController.view.bounds.midX,
                y: alertPresentViewController.view.bounds.midY, width: 0, height: 0)
            popoverPresentationController.permittedArrowDirections = []
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        // add all actions to alert
        actionSheet.addAction(closeAction)
        actionSheet.addAction(cancelAction)
        // show the alert
        alertPresentViewController.present(actionSheet, animated: true, completion: nil)
    }

    func createCloseAllTabsAction() -> UIAction {
        let isPrivate = tabManager.selectedTab?.isPrivate ?? false
        let action = UIAction(
            title: "Close All \(isPrivate ? "Private " : "")Tabs",
            image: UIImage(systemName: "trash"), attributes: .destructive
        ) { _ in
            // make sure the user really wants to close all tabs
            self.showConfirmCloseAllTabs(numberOfTabs: self.getTabCountForCurrentType())
        }
        action.accessibilityLabel = "Close All Tabs"

        return action
    }

    func createCloseAllTabsMenu() -> UIMenu {
        return UIMenu(sections: [[createCloseAllTabsAction()]])
    }

    func getTabCountForCurrentType() -> Int {
        let isPrivate = tabManager.selectedTab?.isPrivate ?? false

        if isPrivate {
            return tabManager.privateTabs.count
        } else {
            return tabManager.normalTabs.count
        }
    }

    // MARK: Recently Closed Tabs
    func createRecentlyClosedTabsMenu() -> UIMenu {
        let recentlyClosed = tabManager.recentlyClosedTabs.joined().filter {
            !InternalURL.isValid(url: ($0.url ?? URL(string: "")))
        }

        var actions = [UIAction]()
        for tab in recentlyClosed {
            let action = UIAction(
                title: tab.title ?? "Untitled", discoverabilityTitle: tab.url?.absoluteString
            ) { _ in
                _ = self.tabManager.restoreSavedTabs([tab])
            }
            action.accessibilityLabel = tab.title ?? "Untitled"
            actions.append(action)
        }

        return UIMenu(title: "Recently Closed", children: actions)
    }

    // MARK: Open Tab
    func createOpenTabMenu(_ tab: SavedTab, openedTab: @escaping (Tab?, Bool) -> Void)
        -> UIContextMenuConfiguration
    {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let newTabAction = UIAction(
                title: "Open in New tab",
                image: UIImage(systemName: "plus.square")
            ) { _ in
                let tab = self.tabManager.restoreSavedTabs([tab], shouldSelectTab: false)
                openedTab(tab, false)
            }

            let newIncognitoTabAction = UIAction(
                title: "Open in New Incognito Tab",
                image: UIImage(named: "incognito")?.withRenderingMode(.alwaysTemplate)
            ) { _ in
                let tab = self.tabManager.restoreSavedTabs(
                    [tab], isPrivate: true, shouldSelectTab: true)
                openedTab(tab, true)
            }

            return UIMenu(children: [newTabAction, newIncognitoTabAction])
        }
    }

    // MARK: Initialization
    init(
        tabManager: TabManager, zeroQueryViewController: ZeroQueryViewController? = nil,
        alertPresentViewController: UIViewController? = nil
    ) {
        self.tabManager = tabManager
        self.zeroQueryViewController = zeroQueryViewController
        self.alertPresentViewController = alertPresentViewController
    }
}
