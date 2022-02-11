// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Combine
import Shared
import SwiftUI

class BrowserModel: ObservableObject {
    @Published var showGrid = false {
        didSet {
            // Ensures toolbars are visible when user closes from the CardGrid.
            // Expand when set to true, so ready when user returns.
            if showGrid {
                scrollingControlModel.showToolbars(animated: true, completion: nil)
            }
        }
    }

    /// Like `!showGrid`, but not animated and only set when the web view should be visible
    @Published private(set) var showContent = true

    let gridModel: GridModel
    let incognitoModel: IncognitoModel
    let tabManager: TabManager

    var cardTransitionModel: CardTransitionModel
    var scrollingControlModel: ScrollingControlModel

    func show() {
        if gridModel.switcherState != .tabs {
            gridModel.switcherState = .tabs
        }
        if gridModel.tabCardModel.allDetails.isEmpty {
            showWithNoAnimation()
        } else {
            cardTransitionModel.update(to: .visibleForTrayShow)
            if showContent {
                showContent = false
            }
            updateSpaces()
        }
    }

    func showWithNoAnimation() {
        cardTransitionModel.update(to: .hidden)
        if showContent {
            showContent = false
        }
        if !showGrid {
            showGrid = true
        }
        updateSpaces()
    }

    func showSpaces(forceUpdate: Bool = true) {
        cardTransitionModel.update(to: .hidden)
        showContent = false
        showGrid = true
        gridModel.switcherState = .spaces

        if forceUpdate {
            updateSpaces()
        }
    }

    func hideWithAnimation() {
        assert(!gridModel.tabCardModel.allDetails.isEmpty)
        cardTransitionModel.update(to: .visibleForTrayHidden)
    }

    func hideWithNoAnimation() {
        cardTransitionModel.update(to: .hidden)
        if showGrid {
            showGrid = false
        }
        if !showContent {
            showContent = true
        }
        gridModel.animateDetailTransitions = true
        if gridModel.showingDetailView {
            gridModel.showingDetailView = false
        }
    }

    func onCompletedCardTransition() {
        if showGrid {
            cardTransitionModel.update(to: .hidden)
            gridModel.animateDetailTransitions = true
        } else {
            hideWithNoAnimation()
            gridModel.animateDetailTransitions = false
        }
    }

    private func updateSpaces() {
        // In preparation for the CardGrid being shown soon, refresh spaces.
        DispatchQueue.main.async {
            SpaceStore.shared.refresh()
        }
    }

    private var followPublicSpaceSubscription: AnyCancellable?

    func openSpace(
        spaceId: String, bvc: BrowserViewController, isPrivate: Bool = false,
        completion: @escaping () -> Void
    ) {
        guard NeevaUserInfo.shared.hasLoginCookie() else {
            var spaceURL = NeevaConstants.appSpacesURL
            spaceURL.appendPathComponent(spaceId)
            bvc.switchToTabForURLOrOpen(spaceURL, isPrivate: isPrivate)
            return
        }

        let existingSpace = gridModel.spaceCardModel.allDetails.first(where: { $0.id == spaceId })
        DispatchQueue.main.async { [self] in
            if incognitoModel.isIncognito {
                tabManager.toggleIncognitoMode()
            }

            if let existingSpace = existingSpace {
                openSpace(spaceID: existingSpace.id)
                gridModel.refreshDetailedSpace()
            } else {
                bvc.showTabTray()
                gridModel.switcherState = .spaces
                gridModel.isLoading = true
            }

            guard existingSpace == nil else {
                return
            }

            SpaceStore.openSpace(spaceId: spaceId) { [self] in
                let spaceCardModel = bvc.gridModel.spaceCardModel
                if let _ = spaceCardModel.allDetails.first(where: { $0.id == spaceId }) {
                    gridModel.isLoading = false
                    openSpace(spaceID: spaceId, animate: false)
                    completion()
                } else {
                    followPublicSpaceSubscription = spaceCardModel.objectWillChange.sink {
                        [unowned self] in
                        if let _ = spaceCardModel.allDetails.first(where: { $0.id == spaceId }) {
                            openSpace(
                                spaceID: spaceId, animate: false)
                            completion()
                            followPublicSpaceSubscription = nil
                        }

                        gridModel.isLoading = false
                    }
                }
            }
        }
    }

    func openSpace(spaceID: String?, animate: Bool = true) {
        withAnimation(nil) {
            showSpaces(forceUpdate: false)
        }

        gridModel.animateDetailTransitions = animate

        guard let spaceID = spaceID,
            let detail = gridModel.spaceCardModel.allDetails.first(where: { $0.id == spaceID })
        else {
            return
        }

        detail.isShowingDetails = true
    }

    func openSpaceDigest(bvc: BrowserViewController) {
        bvc.showTabTray()
        gridModel.switcherState = .spaces

        openSpace(spaceId: SpaceStore.dailyDigestID, bvc: bvc) {}
    }

    init(
        gridModel: GridModel, tabManager: TabManager, chromeModel: TabChromeModel,
        incognitoModel: IncognitoModel
    ) {
        self.gridModel = gridModel
        self.tabManager = tabManager
        self.incognitoModel = incognitoModel
        self.cardTransitionModel = CardTransitionModel()
        self.scrollingControlModel = ScrollingControlModel(
            tabManager: tabManager, chromeModel: chromeModel)
    }
}
