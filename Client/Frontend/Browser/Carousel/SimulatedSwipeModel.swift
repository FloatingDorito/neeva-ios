// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Combine
import Shared
import SwiftUI
import UIKit

class SimulatedSwipeModel: ObservableObject {
    @Published var hidden = true
    @Published var overlayOffset: CGFloat = 0 {
        didSet {
            contentOffset = overlayOffset
        }
    }
    @Published var contentOffset: CGFloat = 0

    let tabManager: TabManager
    let chromeModel: TabChromeModel
    let swipeDirection: SwipeDirection
    var forwardUrlMap = [String: [URL]?]()
    var progressModel = CarouselProgressModel(urls: [], index: 0)

    weak var coordinator: SimulatedSwipeViewRepresentable.Coordinator?
    private var isActive: Bool { coordinator != nil }

    private var subscriptions = Set<AnyCancellable>()

    init(tabManager: TabManager, chromeModel: TabChromeModel, swipeDirection: SwipeDirection) {
        self.tabManager = tabManager
        self.chromeModel = chromeModel
        self.swipeDirection = swipeDirection

        register(self, forTabEvents: .didChangeURL)

        // this pipeline must be created ahead of time and optionally skipped
        // with `isActive` to avoid conflicting assignments between forward and
        // backward models. If pipeline is created during a `TabChromeModel` managed
        // animation, it can cause simultaneous access error when assigning to
        // `TabChromeModel` property due to timing issues.
        tabManager.selectedTabPublisher
            .sink { [weak self] in
                self?.selectedTabChanged(selected: $0)
            }
            .store(in: &subscriptions)
    }

    // MARK: - Back Forward Methods
    func canGoBack() -> Bool {
        return isActive && swipeDirection == .back && !hidden
    }

    func canGoForward() -> Bool {
        return isActive && swipeDirection == .forward && !hidden
    }

    @discardableResult func goBack() -> Bool {
        guard canGoBack(),
            swipeDirection == .back,
            let tab = tabManager.selectedTab
        else {
            return false
        }

        if let _ = tab.parent {
            tabManager.removeTab(tab, showToast: false)
            return true
        } else if let id = tab.parentSpaceID {
            SceneDelegate.getBVC(with: tabManager.scene).browserModel.openSpace(spaceID: id)
            return true
        }

        return false
    }

    @discardableResult func goForward() -> Bool {
        guard canGoForward(),
            swipeDirection == .forward,
            let tab = tabManager.selectedTab,
            let urls = forwardUrlMap[tab.tabUUID]!
        else {
            return false
        }

        let index = urls.firstIndex(of: tab.currentURL()!) ?? -1
        tab.loadRequest(URLRequest(url: urls[index + 1]))
        return true
    }

    // MARK: - Tab Observation Methods
    private func selectedTabChanged(selected: Tab?) {
        guard isActive,
            let tabUUID = selected?.tabUUID
        else {
            return
        }

        switch swipeDirection {
        case .forward:
            updateForwardVisibility(id: tabUUID, results: forwardUrlMap[tabUUID, default: nil])
        case .back:
            updateBackVisibility(tab: selected)
        }
    }

    private func updateBackVisibility(tab: Tab?) {
        guard let tab = tab,
            !tab.canGoBack
        else {
            hidden = true
            return
        }

        // if tab cannot go back, check to see if there's another back target
        if let _ = tab.parent {
            hidden = false
            chromeModel.canGoBack = true
        } else if let id = tab.parentSpaceID, !id.isEmpty {
            hidden = false
            chromeModel.canGoBack = true
        } else {
            // if no back target, hide the simulated swipe
            // and set the back state to the tab's back state
            hidden = true
            chromeModel.canGoBack = tab.canGoBack
        }
    }

    private func updateForwardVisibility(id: String, results: [URL]?, index: Int = -1) {
        forwardUrlMap[id] = results
        hidden = results == nil
        chromeModel.canGoForward = !hidden

        guard let results = results else {
            coordinator?.removeProgressViewFromHierarchy()
            progressModel.urls = []
            progressModel.index = 0
            return
        }

        let bvc = SceneDelegate.getBVC(for: coordinator?.vc?.view)
        coordinator?.addProgressView(to: bvc)
        progressModel.urls = results
        progressModel.index = index

        coordinator?.makeProgressViewConstraints()
    }
}

extension SimulatedSwipeModel: TabEventHandler {
    func tab(_ tab: Tab, didChangeURL url: URL) {
        guard isActive,
            let url = tab.webView?.url,
            tab == tabManager.selectedTab
        else {
            return
        }

        switch swipeDirection {
        case .forward:
            if let query = SearchEngine.current.queryForSearchURL(url),
                !query.isEmpty
            {
                forwardUrlMap[tab.tabUUID] = []
                SearchResultsController.getSearchResults(for: query) { result in
                    switch result {
                    case .failure(let error):
                        let _ = error as NSError
                        self.updateForwardVisibility(id: tab.tabUUID, results: nil)
                    case .success(let results):
                        self.updateForwardVisibility(id: tab.tabUUID, results: results)
                    }
                }
            }

            guard let urls = forwardUrlMap[tab.tabUUID] else {
                return
            }

            guard let index = urls?.firstIndex(of: url), index < (urls?.count ?? 0) - 1 else {
                self.updateForwardVisibility(id: tab.tabUUID, results: nil)
                return
            }

            progressModel.index = index
        case .back:
            updateBackVisibility(tab: tab)
        }
    }
}
