// Copyright Neeva. All rights reserved.

import Foundation

class GridModel: ObservableObject {
    @Published var isHidden = true
    @Published var animationThumbnailState: AnimationThumbnailState = .hidden
    @Published var pickerHeight: CGFloat = UIConstants.TopToolbarHeightWithToolbarButtonsShowing
    @Published var switcherState: SwitcherViews = .tabs
    @Published var showingDetailsAsList = true

    private var updateVisibility: ((Bool) -> Void)!
    var scrollOffset: CGFloat = CGFloat.zero
    var buildCloseAllTabsMenu: (() -> UIMenu)!
    var buildRecentlyClosedTabsMenu: (() -> UIMenu)!

    func show() {
        animationThumbnailState = .visibleForTrayShow
        isHidden = false
        updateVisibility(false)
    }

    func hideWithAnimation() {
        animationThumbnailState = .visibleForTrayHidden
    }

    func hideWithNoAnimation() {
        animationThumbnailState = .visibleForTrayHidden
        updateVisibility(true)
        isHidden = true
        switcherState = .tabs
    }

    func setVisibilityCallback(updateVisibility: @escaping (Bool) -> Void) {
        self.updateVisibility = updateVisibility
    }
}

enum AnimationThumbnailState {
    case hidden
    case visibleForTrayShow
    case visibleForTrayHidden
}
