// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Combine
import Foundation
import Shared
import SwiftUI

class GridModel: ObservableObject {
    let tabCardModel: TabCardModel
    let spaceCardModel: SpaceCardModel

    @Published private(set) var pickerHeight: CGFloat = UIConstants
        .TopToolbarHeightWithToolbarButtonsShowing
    @Published var switcherState: SwitcherViews = .tabs {
        willSet {
            gridCanAnimate = true
        }

        didSet {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.gridCanAnimate = false
            }

            if case .spaces = switcherState {
                ClientLogger.shared.logCounter(
                    .SpacesUIVisited,
                    attributes: EnvironmentHelper.shared.getAttributes())
            }
        }
    }
    @Published var gridCanAnimate = false
    @Published var switchModeWithoutAnimation = false
    @Published var showingDetailView = false {
        didSet {
            // Reset when going from true to false
            if oldValue && !showingDetailView {
                spaceCardModel.detailedSpace?.showingDetails = false
            }
        }
    }
    @Published var needsScrollToSelectedTab: Int = 0
    var scrollToCompletion: (() -> Void)?
    @Published var didVerticalScroll: Int = 0
    @Published var didHorizontalScroll: Int = 0
    @Published var canResizeGrid = true

    // Spaces
    @Published var isLoading = false

    private var subscriptions: Set<AnyCancellable> = []
    private let tabMenu: TabMenu

    init(tabManager: TabManager, tabCardModel: TabCardModel) {
        self.tabCardModel = tabCardModel
        self.spaceCardModel = SpaceCardModel(
            manager: NeevaUserInfo.shared.isUserLoggedIn ? .shared : .suggested)

        self.tabMenu = TabMenu(tabManager: tabManager)
    }

    // Ensure that the selected Card is visible by scrolling it into view
    // synchronously, which causes the selected Card to be generated if
    // needed. Runs `completion` once the selected Card is guaranteed to
    // be visible and responsive to other state changes.
    func scrollToSelectedTab(completion: (() -> Void)? = nil) {
        scrollToCompletion = completion
        needsScrollToSelectedTab += 1
    }

    func switchToTabs(incognito: Bool) {
        switcherState = .tabs

        tabCardModel.manager.switchIncognitoMode(
            incognito: incognito, fromTabTray: true, openLazyTab: false)
    }

    func switchToSpaces() {
        switcherState = .spaces
    }

    func buildCloseAllTabsMenu(sourceView: UIView) -> UIMenu {
        if switcherState == .tabs {
            return UIMenu(sections: [[tabMenu.createCloseAllTabsAction(sourceView: sourceView)]])
        } else {
            return UIMenu()
        }
    }

    func buildRecentlyClosedTabsMenu() -> UIMenu {
        tabMenu.createRecentlyClosedTabsMenu()
    }

    func openSpaceInDetailView(_ space: SpaceCardDetails?) {
        DispatchQueue.main.async { [self] in
            spaceCardModel.detailedSpace = space
            showingDetailView = true
        }
    }

    func openSpaceInDetailView(_ id: String?) {
        guard let id = id else { return }
        DispatchQueue.main.async { [self] in
            spaceCardModel.detailedSpace = SpaceCardDetails(id: id, manager: SpaceStore.shared)
            spaceCardModel.detailedSpace?.refresh()
            showingDetailView = true
        }
    }

    func closeDetailView(switchToTabs: Bool = false) {
        guard showingDetailView else {
            return
        }

        spaceCardModel.detailedSpace?.showingDetails = false
        showingDetailView = false
        spaceCardModel.detailedSpace = nil

        if switchToTabs {
            switcherState = .tabs
        }
    }
}
