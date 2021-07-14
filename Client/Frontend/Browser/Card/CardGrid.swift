// Copyright Neeva. All rights reserved.

import SwiftUI
import Shared

enum SwitcherViews: String, CaseIterable {
    case spaces = "bookmark"
    case tabs = "square.on.square"
}

enum CardGridUX {
    static let PickerPadding: CGFloat = 20
    static let PickerHeight: CGFloat = 50
    static let GridTopPadding: CGFloat = 20
    static let GridSpacing: CGFloat = 20
    static let YStaticOffset: CGFloat = (FeatureFlag[.groupsInSwitcher] ? PickerHeight : 0)
        +  2 * PickerPadding + GridTopPadding + 0.25 * CardUX.DefaultCardSize + CardUX.HeaderSize
}

fileprivate struct CompletionForAnimation: AnimatableModifier {
    var targetValue: Double

    var animatableData: Double {
        didSet {
            maybeRunCompletion()
        }
    }

    var afterTrueToFalse: () -> ()
    var afterFalseToTrue: () -> ()

    init(toggleValue: Bool,
         afterTrueToFalse: @escaping () -> (), afterFalseToTrue: @escaping () -> ()) {
        self.afterTrueToFalse = afterTrueToFalse
        self.afterFalseToTrue = afterFalseToTrue

        self.animatableData = toggleValue ? 1 : 0
        self.targetValue = toggleValue ? 1 : 0
    }

    func maybeRunCompletion() {
        if (animatableData == targetValue) {
            DispatchQueue.main.async {
                targetValue == 1 ? self.afterFalseToTrue() : self.afterTrueToFalse()
            }
        }
    }

    func body(content: Content) -> some View {
        content
    }
}

private extension View {
    func runAfter(toggling: Bool,
                  fromTrueToFalse: @escaping () -> () = {},
                  fromFalseToTrue: @escaping () -> () = {}) -> some View {
        self.modifier(CompletionForAnimation(toggleValue: toggling,
                                             afterTrueToFalse: fromTrueToFalse,
                                             afterFalseToTrue: fromFalseToTrue))
    }
}

enum AnimationThumbnailState {
    case visibleForTrayShown
    case hidden
    case visibleForTrayHidden
}

class GridModel: ObservableObject {
    @Published var isHidden = true
    @Published var animationThumbnailState: AnimationThumbnailState = .visibleForTrayShown
    private var updateVisibility: ((Bool) -> ())!
    var scrollOffset: CGFloat = CGFloat.zero
    var buildCloseAllTabsMenu: (() -> UIMenu)!
    var buildRecentlyClosedTabsMenu: (() -> UIMenu)!

    func show() {
        animationThumbnailState = .visibleForTrayShown
        isHidden = false
        updateVisibility(false)
    }

    func hideWithNoAnimation() {
        updateVisibility(true)
        isHidden = true
        animationThumbnailState = .visibleForTrayShown
    }

    func setVisibilityCallback(updateVisibility: @escaping (Bool) -> ()) {
        self.updateVisibility = updateVisibility
    }
}

struct CardGrid: View {
    @EnvironmentObject var tabModel: TabCardModel
    @EnvironmentObject var tabGroupModel: TabGroupCardModel
    @EnvironmentObject var gridModel: GridModel

    @State var switcherState: SwitcherViews = .tabs
    @State var cardSize: CGFloat = CardUX.DefaultCardSize

    var indexInsideTabGroupModel: Int? {
        guard FeatureFlag[.groupsInSwitcher] else {
            return nil
        }

        let selectedTab = tabModel.manager.selectedTab!
        return tabGroupModel.allDetails
            .firstIndex(where: { $0.id == selectedTab.rootUUID })
    }

    var indexInsideTabModel: Int? {
        let selectedTab = tabModel.manager.selectedTab!
        if FeatureFlag[.groupsInSwitcher] {
            return tabModel.allDetailsWithExclusionList
                .firstIndex(where: { $0.id == selectedTab.tabUUID })
        } else {
            return tabModel.allDetails
                .firstIndex(where: { $0.id == selectedTab.tabUUID })
        }
    }

    var indexInGrid: Int {
        indexInsideTabGroupModel ??
            (FeatureFlag[.groupsInSwitcher] ? tabGroupModel.allDetails.count : 0)
            + indexInsideTabModel!
    }

    var xOffset: CGFloat {
        let offset = (indexInGrid % 2) == 0 ?
            -CardGridUX.GridSpacing / 2 - cardSize / 2 :
            CardGridUX.GridSpacing / 2 + cardSize / 2
        return offset
    }

    var yOffset: CGFloat {
        let rows = floor(CGFloat(indexInGrid) / 2.0)
        return  (CardUX.HeaderSize + cardSize + CardGridUX.GridSpacing) * rows
            + CardGridUX.YStaticOffset + gridModel.scrollOffset
    }

    var selectedThumbnail: some View {
        let selectedTab = tabModel.manager.selectedTab!
        var details: TabCardDetails? = nil

        if FeatureFlag[.groupsInSwitcher] {
            tabGroupModel.allDetails.forEach { groupDetail in
                groupDetail.allDetails.forEach { tabDetail in
                    if tabDetail.id == selectedTab.tabUUID {
                        details = tabDetail
                    }
                }
            }
            tabModel.allDetailsWithExclusionList.forEach { tabDetail in
                if tabDetail.id == selectedTab.tabUUID {
                    details = tabDetail
                }
            }
            return details?.thumbnail
        } else {
            tabModel.allDetails.forEach { tabDetail in
                if tabDetail.id == selectedTab.tabUUID {
                    details = tabDetail
                }
            }
            return details?.thumbnail
        }

    }

    var body: some View {
        GeometryReader { geom in
            ZStack {
                VStack(spacing: 0) {
                    if FeatureFlag[.groupsInSwitcher] {
                        GridPicker(switcherState: $switcherState)
                    }
                    CardsContainer(switcherState: $switcherState,
                                   columns: Array(repeating:
                                                    GridItem(.fixed(cardSize),
                                                             spacing: CardGridUX.GridSpacing),
                                                  count: 2))
                    Spacer(minLength: 0)
                }
                if gridModel.animationThumbnailState != .hidden {
                    selectedThumbnail
                        .runAfter(toggling: gridModel.isHidden, fromTrueToFalse: {
                            gridModel.animationThumbnailState = .hidden
                        }, fromFalseToTrue: {
                            gridModel.hideWithNoAnimation()
                        }).frame(width: gridModel.isHidden ? geom.size.width : cardSize,
                             height: gridModel.isHidden ? geom.size.height : cardSize)
                        .cornerRadius(CardUX.CornerRadius).clipped()
                        .offset(x: gridModel.isHidden ? 0 : xOffset,
                            y: gridModel.isHidden ? 0: yOffset - geom.size.height / 2)
                        .animation(.spring()).onAppear {
                            if !gridModel.isHidden
                                && gridModel.animationThumbnailState == .visibleForTrayHidden {
                                    gridModel.isHidden.toggle()
                            }
                        }
                }
            }.onChange(of: geom.size.width) { _ in
                self.cardSize = (geom.size.width - 3 * CardGridUX.GridSpacing) / 2
            }.onAppear {
                self.cardSize = (geom.size.width - 3 * CardGridUX.GridSpacing) / 2
            }
        }
    }
}

struct CardsContainer: View {
    @EnvironmentObject var tabModel: TabCardModel
    @EnvironmentObject var tabGroupModel: TabGroupCardModel
    @EnvironmentObject var gridModel: GridModel

    @Binding var switcherState: SwitcherViews
    let columns: [GridItem]

    var indexInsideTabGroupModel: Int? {
        let selectedTab = tabModel.manager.selectedTab!
        return tabGroupModel.allDetails
            .firstIndex(where: { $0.id == selectedTab.rootUUID })
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ScrollViewReader { value in
                LazyVGrid(columns: columns, spacing: CardGridUX.GridSpacing) {
                    if case .spaces = switcherState {
                        SpaceCardsView()
                            .environment(\.selectionCompletion) {
                                gridModel.hideWithNoAnimation()
                                switcherState = .tabs
                                value.scrollTo(tabModel.manager.selectedTab?.tabUUID)
                            }
                    } else {
                        TabCardsView().environment(\.selectionCompletion) {
                            withAnimation {
                                value.scrollTo(
                                    indexInsideTabGroupModel != nil ?
                                        tabModel.manager.selectedTab?.rootUUID :
                                        tabModel.manager.selectedTab?.tabUUID)
                            }
                            gridModel.animationThumbnailState = .visibleForTrayHidden
                        }
                    }
                }.padding(.top, 20).onAppear {
                    value.scrollTo(
                        indexInsideTabGroupModel != nil ?
                            tabModel.manager.selectedTab?.rootUUID :
                            tabModel.selectedTabID)
                }.onChange(of: tabModel.selectedTabID) { _ in
                    value.scrollTo(
                        indexInsideTabGroupModel != nil ?
                            tabModel.manager.selectedTab?.rootUUID :
                            tabModel.selectedTabID)
                }.background(GeometryReader { proxy in
                    Color.clear.preference(key: ScrollViewOffsetPreferenceKey.self,
                                           value:  proxy.frame(in: .named("scroll")).minY)
                })
            }
        }.coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { scrollOffset in
            gridModel.scrollOffset = scrollOffset
        }
    }
}

struct SpaceCardsView: View {
    @EnvironmentObject var spacesModel: SpaceCardModel

    var body: some View {
        ForEach(spacesModel.allDetails, id: \.id) { details in
            Card(details: details, config: .grid)
                .id(details.id)
        }
    }
}

struct TabCardsView: View {
    @EnvironmentObject var tabModel: TabCardModel
    @EnvironmentObject var tabGroupModel: TabGroupCardModel

    var body: some View {
        Group {
            if FeatureFlag[.groupsInSwitcher] {
                ForEach(tabGroupModel.allDetails, id: \.id) { details in
                    Card(details: details, config: .grid)
                        .id(details.id)
                }
                ForEach(tabModel.allDetailsWithExclusionList, id: \.id) { details in
                    Card(details: details, config: .grid)
                        .id(details.id)
                }
            } else {
                ForEach(tabModel.allDetails, id: \.id) { details in
                    Card(details: details, config: .grid)
                        .id(details.id)
                }
            }

        }
    }
}

struct GridPicker: View {
    @Binding var switcherState: SwitcherViews

    var body: some View {
        Picker("", selection: $switcherState) {
            ForEach(SwitcherViews.allCases, id: \.rawValue) { view in
                Image(systemName: view.rawValue).tag(view).frame(width: 64)
            }
        }.pickerStyle(SegmentedPickerStyle())
            .background(Color.DefaultBackground)
            .padding(CardGridUX.PickerPadding)
            .frame(width: 160, height: CardGridUX.PickerHeight)
    }
}

struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }

    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
}
