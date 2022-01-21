// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Combine
import Shared
import SwiftUI
import web3swift

// For sharing to work, this must currently be the BrowserViewController
protocol TopBarDelegate: ToolbarDelegate {
    func urlBarReloadMenu() -> UIMenu?
    func urlBarDidPressStop()
    func urlBarDidPressReload()
    func urlBarDidEnterOverlayMode()
    func urlBarDidLeaveOverlayMode()
    func urlBar(didSubmitText text: String, isSearchQuerySuggestion: Bool)

    func perform(neevaMenuAction: NeevaMenuAction)
    func updateFeedbackImage()

    var tabContainerModel: TabContainerModel { get }
    var tabManager: TabManager { get }
    var searchQueryModel: SearchQueryModel { get }
}

struct TopBarContent: View {
    let browserModel: BrowserModel
    let suggestionModel: SuggestionModel
    let model: LocationViewModel
    let queryModel: SearchQueryModel
    let gridModel: GridModel
    let trackingStatsViewModel: TrackingStatsViewModel
    let chromeModel: TabChromeModel
    let readerModeModel: ReaderModeModel
    let web3Model: Web3Model

    let newTab: () -> Void
    let onCancel: () -> Void

    var body: some View {
        TopBarView(
            performTabToolbarAction: { chromeModel.topBarDelegate?.performTabToolbarAction($0) },
            buildTabsMenu: { chromeModel.topBarDelegate?.tabToolbarTabsMenu(sourceView: $0) },
            onReload: {
                switch chromeModel.reloadButton {
                case .reload:
                    chromeModel.topBarDelegate?.urlBarDidPressReload()
                case .stop:
                    chromeModel.topBarDelegate?.urlBarDidPressStop()
                }
            },
            onSubmit: {
                chromeModel.topBarDelegate?.urlBar(
                    didSubmitText: $0, isSearchQuerySuggestion: false)
            },
            onShare: { shareView in
                // also update in LegacyTabToolbarHelper
                ClientLogger.shared.logCounter(
                    .ClickShareButton, attributes: EnvironmentHelper.shared.getAttributes())
                guard
                    let bvc = chromeModel.topBarDelegate as? BrowserViewController,
                    let tab = bvc.tabManager.selectedTab,
                    let url = tab.url
                else { return }
                if url.isFileURL {
                    bvc.share(fileURL: url, buttonView: shareView, presentableVC: bvc)
                } else {
                    bvc.share(tab: tab, from: shareView, presentableVC: bvc)
                }
            },
            buildReloadMenu: { chromeModel.topBarDelegate?.urlBarReloadMenu() },
            onNeevaMenuAction: { chromeModel.topBarDelegate?.perform(neevaMenuAction: $0) },
            newTab: newTab,
            onCancel: onCancel,
            onOverflowMenuAction: {
                chromeModel.topBarDelegate?.perform(overflowMenuAction: $0, targetButtonView: $1)
            }
        )
        .environmentObject(browserModel)
        .environmentObject(suggestionModel)
        .environmentObject(model)
        .environmentObject(queryModel)
        .environmentObject(gridModel)
        .environmentObject(trackingStatsViewModel)
        .environmentObject(chromeModel)
        .environmentObject(readerModeModel)
        .environmentObject(web3Model)
    }
}

class TopBarHost: IncognitoAwareHostingController<TopBarContent> {
    var chromeModel: TabChromeModel

    private var height: NSLayoutConstraint?
    private var inlineToolbarHeight: CGFloat {
        return SceneDelegate.getKeyWindow(for: view).safeAreaInsets.top
            + UIConstants.TopToolbarHeightWithToolbarButtonsShowing
            + (chromeModel.showTopCardStrip ? CardControllerUX.Height : 0)
    }
    private var portraitHeight: CGFloat {
        return SceneDelegate.getKeyWindow(for: view).safeAreaInsets.top
            + UIConstants.PortraitToolbarHeight
            + (chromeModel.showTopCardStrip ? CardControllerUX.Height : 0)
    }

    private var isEditingListener: AnyCancellable?

    init(
        isIncognito: Bool,
        browserModel: BrowserModel,
        locationViewModel: LocationViewModel,
        suggestionModel: SuggestionModel,
        queryModel: SearchQueryModel,
        gridModel: GridModel,
        trackingStatsViewModel: TrackingStatsViewModel,
        chromeModel: TabChromeModel,
        readerModeModel: ReaderModeModel,
        web3Model: Web3Model,
        delegate: TopBarDelegate,
        newTab: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.chromeModel = chromeModel
        super.init(isIncognito: isIncognito)

        setRootView {
            TopBarContent(
                browserModel: browserModel,
                suggestionModel: suggestionModel,
                model: locationViewModel,
                queryModel: queryModel,
                gridModel: gridModel,
                trackingStatsViewModel: trackingStatsViewModel,
                chromeModel: chromeModel,
                readerModeModel: readerModeModel,
                web3Model: web3Model,
                newTab: newTab,
                onCancel: onCancel
            )
        }

        DispatchQueue.main.async { [self] in
            // Prevents the top bar from shrinking in portait mode and from being to tall in landscape
            self.height = self.view.heightAnchor.constraint(
                equalToConstant: chromeModel.inlineToolbar ? inlineToolbarHeight : portraitHeight)
            self.height?.isActive = true
        }

        isEditingListener = chromeModel.$isEditingLocation.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateHeight()
            }
        }

        self.view.backgroundColor = .clear
        self.view.translatesAutoresizingMaskIntoConstraints = false
        self.view.setContentHuggingPriority(.required, for: .vertical)
    }

    override func viewWillTransition(
        to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator
    ) {
        coordinator.animate(
            alongsideTransition: {
                [self] (UIViewControllerTransitionCoordinatorContext) -> Void in
                height?.constant = chromeModel.inlineToolbar ? inlineToolbarHeight : portraitHeight
            },
            completion: { (UIViewControllerTransitionCoordinatorContext) -> Void in
                print("rotation completed")
            })

        super.viewWillTransition(to: size, with: coordinator)
    }

    func updateHeight() {
        height?.constant = chromeModel.inlineToolbar ? inlineToolbarHeight : portraitHeight
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
