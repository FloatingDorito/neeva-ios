// Copyright Neeva. All rights reserved.

import Shared
import SwiftUI

/// Custom animator that transitions between the tab switcher and a tab
struct CardTransitionAnimator: View {
    let cardSize: CGFloat
    /// The size of the area where tab content is displayed when outside the tab switcher
    let containerSize: CGSize
    let safeAreaInsets: EdgeInsets
    /// Whether the toolbar is displayed at the top of the tab switcher
    let topToolbar: Bool
    let animation: Animation = .interpolatingSpring(stiffness: 425, damping: 30)

    @EnvironmentObject private var gridModel: GridModel
    @EnvironmentObject var tabModel: TabCardModel
    @EnvironmentObject var tabGroupModel: TabGroupCardModel

    var isSelectedTabInGroup: Bool {
        let selectedTab = tabModel.manager.selectedTab!
        return tabGroupModel.representativeTabs.contains { $0.rootUUID == selectedTab.rootUUID }
    }

    private var transitionBottomPadding: CGFloat {
        return topToolbar ? 0 : UIConstants.ToolbarHeight + safeAreaInsets.bottom
    }

    private var transitionTopPadding: CGFloat {
        gridModel.pickerHeight + safeAreaInsets.top
    }

    var selectedCardDetails: TabCardDetails? {
        return tabModel.allDetailsWithExclusionList.first(where: \.isSelected)
            ?? tabGroupModel.allDetails
            .compactMap { $0.allDetails.first(where: \.isSelected) }
            .first
    }

    var maxWidth: CGFloat {
        containerSize.width + safeAreaInsets.leading + safeAreaInsets.trailing
    }

    var maxHeight: CGFloat {
        containerSize.height + safeAreaInsets.bottom - transitionBottomPadding
            - transitionTopPadding + safeAreaInsets.top + CardUX.HeaderSize
    }

    var selectedTabGroupFrame: CGRect {
        if let tab = tabModel.manager.selectedTab, let frame = gridModel.cardFrames[tab.rootUUID] {
            return frame
        }
        return .zero
    }

    var selectedTabFrame: CGRect {
        if let tab = tabModel.manager.selectedTab, let frame = gridModel.cardFrames[tab.tabUUID] {
            return frame
        }
        return .zero
    }

    var frame: CGRect {
        gridModel.isHidden
            ? CGRect(width: maxWidth, height: maxHeight)
            : ((isSelectedTabInGroup && gridModel.animationThumbnailState == .visibleForTrayShow)
                ? selectedTabGroupFrame : selectedTabFrame).offsetBy(
                    dx: 0, dy: -transitionTopPadding)
    }

    var body: some View {
        Group {
            if let selectedCardDetails = selectedCardDetails {
                Card(
                    details: selectedCardDetails, showsSelection: !gridModel.isHidden,
                    animate: true,
                    reportFrame: false
                )
                .runAfter(
                    toggling: gridModel.isHidden,
                    fromTrueToFalse: {
                        gridModel.animationThumbnailState = .hidden
                    },
                    fromFalseToTrue: {
                        gridModel.scrollToSelectedTab()
                        gridModel.hideWithNoAnimation()
                        tabGroupModel.detailedTabGroup = nil
                    }
                )
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.origin.x, y: frame.origin.y)
                .frame(width: maxWidth, height: maxHeight, alignment: .topLeading)
                .allowsHitTesting(false)
                .clipped()
                .padding(.top, transitionTopPadding)
                .padding(.bottom, transitionBottomPadding)
                .ignoresSafeArea()
            } else {
                Color.clear
            }
        }
        .useEffect(deps: gridModel.animationThumbnailState) { _ in
            /// In addition to making the grid visible, we need to make sure that the
            /// card for the selected tab is visible. When showing the card grid, we
            /// want to do that upfront. When hiding the card grid, we want to do that
            /// after the animation completes. See `fromFalseToTrue` above.
            switch gridModel.animationThumbnailState {
            case .visibleForTrayShow:
                gridModel.scrollToSelectedTab()
                withAnimation(animation) {
                    gridModel.isHidden = false
                }
            case .visibleForTrayHidden:
                withAnimation(animation) {
                    gridModel.isHidden = true
                }
            case .hidden:
                break
            }
        }
    }
}
