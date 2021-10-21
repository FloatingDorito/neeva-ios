// Copyright Neeva. All rights reserved.

import Foundation

class GridModel: ObservableObject {
    @Published var isHidden = true
    @Published var animationThumbnailState: AnimationThumbnailState = .hidden
    @Published var pickerHeight: CGFloat = UIConstants.TopToolbarHeightWithToolbarButtonsShowing
    @Published var switcherState: SwitcherViews = .tabs {
        didSet {
            if case .spaces = switcherState {
                ClientLogger.shared.logCounter(
                    .SpacesUIVisited,
                    attributes: EnvironmentHelper.shared.getAttributes())
            }
        }
    }

    private var updateVisibility: ((Bool) -> Void)!
    var buildCloseAllTabsMenu: (() -> UIMenu)!
    var buildRecentlyClosedTabsMenu: (() -> UIMenu)!
    var animateDetailTransitions = true
    let coordinateSpaceName: String = UUID().uuidString
    @Published var selectedCardFrame: CGRect = .zero
    @Published var selectedTabGroupFrame: CGRect = .zero

    func show() {
        animationThumbnailState = .visibleForTrayShow
        updateVisibility(false)
    }

    func showWithNoAnimation() {
        animationThumbnailState = .hidden
        isHidden = false
        updateVisibility(false)
    }

    func showSpaces() {
        animationThumbnailState = .hidden
        switcherState = .spaces
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
        animateDetailTransitions = true
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
