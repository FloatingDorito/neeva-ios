// Copyright Neeva. All rights reserved.

import Shared
import SwiftUI

struct TopBarView: View {
    let performTabToolbarAction: (ToolbarAction) -> Void
    let buildTabsMenu: () -> UIMenu?
    let onReload: () -> Void
    let onSubmit: (String) -> Void
    let onShare: (UIView) -> Void
    let buildReloadMenu: () -> UIMenu?
    let onNeevaMenuAction: (NeevaMenuAction) -> Void
    let didTapNeevaMenu: () -> Void
    let newTab: () -> Void
    let onCancel: () -> Void
    let onOverflowMenuAction: (OverflowMenuAction, UIView) -> Void
    let onLongPressOverflowButton: (UIView) -> Void

    @State private var shouldInsetHorizontally = false

    @EnvironmentObject private var chrome: TabChromeModel
    @EnvironmentObject private var location: LocationViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: chrome.inlineToolbar ? 12 : 0) {
                if chrome.inlineToolbar {
                    TabToolbarButtons.BackButton(
                        weight: .regular,
                        onBack: { performTabToolbarAction(.back) },
                        onLongPress: { performTabToolbarAction(.longPressBackForward) }
                    ).tapTargetFrame()

                    TabToolbarButtons.ForwardButton(
                        weight: .regular,
                        onForward: { performTabToolbarAction(.forward) },
                        onLongPress: { performTabToolbarAction(.longPressBackForward) }
                    ).tapTargetFrame()

                    TabToolbarButtons.ReloadStopButton(
                        weight: .regular,
                        onTap: { performTabToolbarAction(.reloadStop) }
                    ).tapTargetFrame()

                    TopBarOverflowMenuButton(
                        changedUserAgent:
                            chrome.topBarDelegate?.tabManager.selectedTab?.showRequestDesktop,
                        onOverflowMenuAction: onOverflowMenuAction,
                        onLongPress: onLongPressOverflowButton,
                        location: .tab,
                        inTopBar: true
                    )
                }
                TabLocationView(
                    onReload: onReload, onSubmit: onSubmit, onShare: onShare,
                    buildReloadMenu: buildReloadMenu, onCancel: onCancel
                )
                .padding(.horizontal, chrome.inlineToolbar ? 0 : 8)
                .padding(.top, chrome.inlineToolbar ? 8 : 3)
                // -1 for the progress bar
                .padding(.bottom, (chrome.inlineToolbar ? 8 : 10) - 1)
                .layoutPriority(1)
                if chrome.inlineToolbar {
                    TopBarNeevaMenuButton(
                        onTap: {
                            chrome.hideZeroQuery()
                            didTapNeevaMenu()
                        }, onNeevaMenuAction: onNeevaMenuAction)

                    TabToolbarButtons.AddToSpace(
                        weight: .regular, action: { performTabToolbarAction(.addToSpace) }
                    )
                    .tapTargetFrame()

                    TabToolbarButtons.ShowTabs(
                        weight: .regular, action: { performTabToolbarAction(.showTabs) },
                        buildMenu: buildTabsMenu
                    )
                    .tapTargetFrame()

                    if FeatureFlag[.cardStrip] {
                        Button(action: newTab) {
                            Symbol(.plusApp, label: "New Tab")
                        }
                    }
                }
            }
            .opacity(chrome.controlOpacity)
            .padding(.horizontal, shouldInsetHorizontally ? 12 : 0)
            .padding(.bottom, chrome.estimatedProgress == nil ? 0 : -1)

            Group {
                if let progress = chrome.estimatedProgress {
                    ProgressView(value: progress)
                        .progressViewStyle(PageProgressBarStyle())
                        .padding(.bottom, -1)
                        .zIndex(1)
                        .ignoresSafeArea(edges: .horizontal)
                }
            }
            .transition(.opacity)

            Color.ui.adaptive.separator.frame(height: 0.5).ignoresSafeArea()
        }
        .background(
            GeometryReader { geom in
                let shouldInsetHorizontally =
                    geom.safeAreaInsets.leading == 0 && geom.safeAreaInsets.trailing == 0
                    && chrome.inlineToolbar
                Color.clear
                    .useEffect(deps: shouldInsetHorizontally) { self.shouldInsetHorizontally = $0 }
            }
        )
        .animation(.default, value: chrome.estimatedProgress)
        .background(Color.DefaultBackground.ignoresSafeArea())
        .accentColor(.label)
    }
}

struct TopBarView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                TopBarView(
                    performTabToolbarAction: { _ in }, buildTabsMenu: { nil }, onReload: {},
                    onSubmit: { _ in }, onShare: { _ in }, buildReloadMenu: { nil },
                    onNeevaMenuAction: { _ in }, didTapNeevaMenu: {}, newTab: {}, onCancel: {},
                    onOverflowMenuAction: { _, _ in }, onLongPressOverflowButton: { _ in })
                Spacer()
            }.background(Color.red.ignoresSafeArea())

            VStack {
                TopBarView(
                    performTabToolbarAction: { _ in }, buildTabsMenu: { nil }, onReload: {},
                    onSubmit: { _ in }, onShare: { _ in }, buildReloadMenu: { nil },
                    onNeevaMenuAction: { _ in }, didTapNeevaMenu: {}, newTab: {}, onCancel: {},
                    onOverflowMenuAction: { _, _ in }, onLongPressOverflowButton: { _ in })
                Spacer()
            }
            .preferredColorScheme(.dark)
        }
        .environmentObject(LocationViewModel(previewURL: nil, isSecure: true))
        .environmentObject(GridModel())
        .environmentObject(TabChromeModel(estimatedProgress: 0.5))
    }
}
