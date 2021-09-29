// Copyright Neeva. All rights reserved.

import Shared
import SwiftUI

/// Custom animator that transitions between the tab switcher and a tab
struct CardTransitionAnimator: View {
    let cardSize: CGFloat
    let columnCount: Int
    /// The location of the card in the tab switcher, relative to the container of the scroll view
    var offset: CGPoint {
        let point =
            CGPoint(
                x: CardGridUX.GridSpacing
                    + (CardGridUX.GridSpacing + cardSize) * (indexInGrid % columnCount),
                y: (CardUX.HeaderSize + CardGridUX.GridSpacing + cardSize
                    * CardUX.DefaultTabCardRatio) * row
            )
        return point
    }
    /// The size of the area where tab content is displayed when outside the tab switcher
    let containerSize: CGSize
    let safeAreaInsets: EdgeInsets
    /// Whether the toolbar is displayed at the top of the tab switcher
    let topToolbar: Bool

    @EnvironmentObject private var gridModel: GridModel
    @EnvironmentObject var tabModel: TabCardModel
    @EnvironmentObject var tabGroupModel: TabGroupCardModel

    private var transitionBottomPadding: CGFloat {
        return topToolbar ? 0 : UIConstants.ToolbarHeight + safeAreaInsets.bottom
    }

    private var transitionTopPadding: CGFloat {
        gridModel.pickerHeight + safeAreaInsets.top
    }

    var indexInsideTabModel: Int? {
        if FeatureFlag[.groupsInSwitcher] {
            return tabModel.allDetailsWithExclusionList.firstIndex(where: \.isSelected)
        } else {
            return tabModel.allDetails.firstIndex(where: \.isSelected)
        }
    }

    var indexInsideCombinedList: Int? {
        let combinedList = tabModel.allDetails.filter { tabCard in
            (tabGroupModel.representativeTabs.contains(
                tabCard.manager.get(for: tabCard.id)!)
                || tabModel.allDetailsWithExclusionList.contains { $0.id == tabCard.id })
        }
        let selectedTab = tabModel.manager.selectedTab!
        return combinedList.firstIndex {
            $0.isSelected
                || $0.manager.get(for: $0.id)?.rootUUID == tabModel.manager.selectedTab!.rootUUID
        }
    }

    var indexWithinTabGroup: Int? {
        let selectedTab = tabModel.manager.selectedTab!
        let tabGroupDetail = tabGroupModel.allDetails.first { $0.id == selectedTab.rootUUID }
        return tabGroupDetail?.allDetails.firstIndex { $0.manager.get(for: $0.id)! == selectedTab }

    }

    var indexInGrid: Int {
        let selectedTab = tabModel.manager.selectedTab!
        return FeatureFlag[.groupsInSwitcher]
            ? (tabGroupModel.representativeTabs.contains { $0.rootUUID == selectedTab.rootUUID }
                ? indexWithinTabGroup! : indexInsideCombinedList!) : indexInsideTabModel!
    }

    var selectedCardDetails: TabCardDetails? {
        if FeatureFlag[.groupsInSwitcher] {
            return tabModel.allDetailsWithExclusionList.first(where: \.isSelected)
                ?? tabGroupModel.allDetails
                .compactMap { $0.allDetails.first(where: \.isSelected) }
                .first
        } else {
            return tabModel.allDetails.first(where: \.isSelected)
        }
    }

    var row: CGFloat {
        floor(CGFloat(indexInGrid) / columnCount)
    }

    var body: some View {
        let maxWidth = containerSize.width + safeAreaInsets.leading + safeAreaInsets.trailing
        let maxHeight =
            containerSize.height + safeAreaInsets.bottom - transitionBottomPadding
            - transitionTopPadding + safeAreaInsets.top + CardUX.HeaderSize
        if let selectedCardDetails = selectedCardDetails {
            Card(details: selectedCardDetails, showsSelection: !gridModel.isHidden, animate: true)
                .runAfter(
                    toggling: gridModel.isHidden,
                    fromTrueToFalse: {
                        gridModel.animationThumbnailState = .hidden
                    },
                    fromFalseToTrue: {
                        gridModel.hideWithNoAnimation()
                    }
                )
                .frame(
                    width: gridModel.isHidden ? maxWidth : cardSize,
                    height: gridModel.isHidden
                        ? maxHeight : cardSize * CardUX.DefaultTabCardRatio + CardUX.HeaderSize
                )
                .offset(
                    x: gridModel.isHidden ? 0 : offset.x + safeAreaInsets.leading,
                    y: gridModel.isHidden ? 0 : offset.y + gridModel.scrollOffset
                )
                .animation(.interpolatingSpring(stiffness: 425, damping: 30))
                .useEffect(deps: gridModel.animationThumbnailState) { _ in
                    if !gridModel.isHidden
                        && gridModel.animationThumbnailState == .visibleForTrayHidden
                    {
                        gridModel.isHidden.toggle()
                    }
                }
                .frame(width: maxWidth, height: maxHeight, alignment: .topLeading)
                .allowsHitTesting(false)
                .clipped()
                .padding(.top, transitionTopPadding)
                .padding(.bottom, transitionBottomPadding)
                .ignoresSafeArea()
        }
    }
}

//struct CardTransitionAnimator_Previews: PreviewProvider {
//    static var previews: some View {
//        CardTransitionAnimator()
//    }
//}
