// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Shared
import SwiftUI
import UIKit

enum SwipeDirection {
    case forward, back
}

public enum SwipeUX {
    static let EdgeWidth: CGFloat = 30
}

class SimulatedSwipeController:
    UIViewController, TabEventHandler, TabManagerDelegate, SimulateForwardAnimatorDelegate
{

    func simulateForwardAnimatorStartedSwipe(_ animator: SimulatedSwipeAnimator) {
        if swipeDirection == .forward {
            self.goForward()
        }
    }

    func simulateForwardAnimatorFinishedSwipe(_ animator: SimulatedSwipeAnimator) {
        if swipeDirection == .back {
            self.goBack()
        }
    }

    var animator: SimulatedSwipeAnimator!
    var blankView: UIView!
    var tabManager: TabManager
    var chromeModel: TabChromeModel
    var forwardUrlMap = [String: [URL]?]()
    var swipeDirection: SwipeDirection
    var progressModel = CarouselProgressModel(urls: [], index: 0)

    var progressView: UIHostingController<CarouselProgressView>!

    init(
        tabManager: TabManager, chromeModel: TabChromeModel, swipeDirection: SwipeDirection
    ) {
        self.tabManager = tabManager
        self.chromeModel = chromeModel
        self.swipeDirection = swipeDirection
        super.init(nibName: nil, bundle: nil)

        register(self, forTabEvents: .didChangeURL)
        tabManager.addDelegate(self)

        self.animator = SimulatedSwipeAnimator(
            swipeDirection: swipeDirection,
            simulatedSwipeControllerView: self.view,
            tabManager: tabManager)
        self.animator.delegate = self

        if swipeDirection == .forward {
            self.progressView = UIHostingController(
                rootView: CarouselProgressView(model: progressModel))
            self.progressView.view.backgroundColor = .clear
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        blankView = UIView()
        blankView.backgroundColor = .white
        self.view.addSubview(blankView)

        blankView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.width.equalToSuperview().offset(-SwipeUX.EdgeWidth)

            switch swipeDirection {
            case .forward:
                make.trailing.equalToSuperview()
            case .back:
                make.leading.equalToSuperview()
            }
        }
    }

    func tab(_ tab: Tab, didChangeURL url: URL) {
        guard let url = tab.webView?.url, tab == tabManager.selectedTab else {
            return
        }

        switch swipeDirection {
        case .forward:
            if let query = SearchEngine.current.queryForSearchURL(url), !query.isEmpty {
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

            guard let urls = self.forwardUrlMap[tab.tabUUID] else {
                return
            }

            guard let index = urls?.firstIndex(of: url), index < (urls?.count ?? 0) - 1 else {
                self.updateForwardVisibility(id: tab.tabUUID, results: nil)
                return
            }

            self.progressModel.index = index
        case .back:
            updateBackVisibility(tab: tab)
        }

    }

    func tabManager(
        _ tabManager: TabManager, didSelectedTabChange selected: Tab?, previous: Tab?,
        isRestoring: Bool, updateZeroQuery: Bool
    ) {
        guard let tabUUID = selected?.tabUUID else {
            return
        }

        switch swipeDirection {
        case .forward:
            updateForwardVisibility(id: tabUUID, results: self.forwardUrlMap[tabUUID] ?? nil)
        case .back:
            updateBackVisibility(tab: selected)
        }
    }

    func updateBackVisibility(tab: Tab?) {
        guard let tab = tab else {
            view.isHidden = true
            return
        }
        if tab.canGoBack {
            view.isHidden = true
        } else if let _ = tab.parent {
            view.isHidden = false
            chromeModel.canGoBack = true
        } else if let id = tab.parentSpaceID, !id.isEmpty {
            view.isHidden = false
            chromeModel.canGoBack = true
        }
    }

    func updateForwardVisibility(id: String, results: [URL]?, index: Int = -1) {
        forwardUrlMap[id] = results
        view.isHidden = results == nil
        chromeModel.canGoForward = !view.isHidden

        guard let results = results else {
            progressView.view.removeFromSuperview()
            progressView.removeFromParent()
            progressModel.urls = []
            progressModel.index = 0
            return
        }

        let bvc = SceneDelegate.getBVC(for: view)
        bvc.addChild(progressView)
        bvc.view.addSubview(progressView.view)
        progressView.didMove(toParent: bvc)
        progressModel.urls = results
        progressModel.index = index
        progressView.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bvc.view.snp.bottom)
                .offset(-UIConstants.BottomToolbarHeight)
        }
    }

    func canGoBack() -> Bool {
        swipeDirection == .back && !view.isHidden
    }

    @discardableResult func goBack() -> Bool {
        guard canGoBack(), swipeDirection == .back, let tab = tabManager.selectedTab else {
            return false
        }

        if let _ = tab.parent {
            tabManager.removeTabAndUpdateSelectedTab(tab)
        } else if let id = tab.parentSpaceID {
            SceneDelegate.getBVC(with: tabManager.scene).browserModel.openSpace(spaceID: id)
        } else {
            return false
        }

        return true
    }

    func canGoForward() -> Bool {
        swipeDirection == .forward && !view.isHidden
    }

    @discardableResult func goForward() -> Bool {
        guard canGoForward(), swipeDirection == .forward, let tab = tabManager.selectedTab,
            let urls = forwardUrlMap[tab.tabUUID]!
        else {
            return false
        }

        let index = urls.firstIndex(of: tab.currentURL()!) ?? -1
        // If we are here, we have already fake animated and it is too late
        assert(index < urls.count - 1)
        tab.loadRequest(URLRequest(url: urls[index + 1]))
        return true
    }

    func tabManager(_ tabManager: TabManager, didAddTab tab: Tab, isRestoring: Bool) {}

    func tabManager(_ tabManager: TabManager, didRemoveTab tab: Tab, isRestoring: Bool) {}

    func tabManagerDidRestoreTabs(_ tabManager: TabManager) {}

    func tabManagerDidAddTabs(_ tabManager: TabManager) {}

    func tabManagerDidRemoveAllTabs(_ tabManager: TabManager) {}
}
