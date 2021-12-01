// Copyright Neeva. All rights reserved.

import Shared
import SwiftUI

enum SwitcherViews: String, CaseIterable {
    case tabs = "Tabs"
    case spaces = "Spaces"
}

enum CardGridUX {
    static let PickerPadding: CGFloat = 20
    static let GridSpacing: CGFloat = 20
}

struct CardGrid: View {
    @EnvironmentObject var tabModel: TabCardModel
    @EnvironmentObject var tabGroupModel: TabGroupCardModel
    @EnvironmentObject var spaceModel: SpaceCardModel
    @EnvironmentObject var gridModel: GridModel

    @State private var cardSize: CGFloat = CardUX.DefaultCardSize
    @State private var columnCount = 2
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State var detailDragOffset: CGFloat = 0

    var topToolbar: Bool {
        verticalSizeClass == .compact || horizontalSizeClass == .regular
    }

    var columns: [GridItem] {
        return Array(
            repeating:
                GridItem(
                    .fixed(cardSize),
                    spacing: CardGridUX.GridSpacing),
            count: columnCount)
    }

    @ViewBuilder var cardContainerBackground: some View {
        if tabModel.isCardGridEmpty, case .tabs = gridModel.switcherState {
            EmptyCardGrid()
        } else {
            Color(UIColor.TrayBackground).ignoresSafeArea()
        }
    }

    @ViewBuilder var cardContainer: some View {
        VStack(spacing: 0) {
            CardsContainer(
                columns: columns
            )
            .environment(\.cardSize, cardSize)
            Spacer(minLength: 0)
        }
        .background(cardContainerBackground)
    }

    @ViewBuilder var topBar: some View {
        if topToolbar {
            SwitcherToolbarView(top: true, isEmpty: tabModel.isCardGridEmpty)
        } else {
            GridPicker()
        }
    }

    @ViewBuilder var grid: some View {
        VStack(spacing: 0) {
            topBar
            cardContainer
            if !topToolbar {
                SwitcherToolbarView(top: false, isEmpty: tabModel.isCardGridEmpty)
                    .frame(height: UIConstants.ToolbarHeight)
            }
        }
    }

    @ViewBuilder var loadingIndicator: some View {
        ZStack {
            Color.TrayBackground
                .opacity(0.5)

            RoundedRectangle(cornerRadius: 8)
                .foregroundColor(Color(UIColor.DefaultBackground))
                .shadow(color: .black.opacity(0.1), radius: 12)
                .frame(width: 50, height: 50)

            ProgressView()
        }
    }

    func updateCardSize(width: CGFloat, topToolbar: Bool) {
        if width > 1000 {
            columnCount = 4
        } else {
            columnCount = topToolbar ? 3 : 2
        }
        self.cardSize = (width - (columnCount + 1) * CardGridUX.GridSpacing) / columnCount
    }

    var body: some View {
        GeometryReader { geom in
            ZStack {
                grid
                    .offset(
                        x: (spaceModel.detailedSpace == nil
                            && tabGroupModel.detailedTabGroup == nil)
                            ? 0 : -(geom.size.width - detailDragOffset) / 5, y: 0
                    )
                    .background(
                        gridModel.animationThumbnailState == .hidden
                            ? Color.TrayBackground : Color.clear
                    )
                    .modifier(
                        SwipeToSwitchToSpacesGesture(gridModel: gridModel, tabModel: tabModel))

                if gridModel.isLoading {
                    loadingIndicator
                }

                Group {
                    if let spaceDetails = spaceModel.detailedSpace {
                        DetailView(primitive: spaceDetails) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                detailDragOffset = geom.size.width
                            }
                        }
                        .frame(width: geom.size.width, height: geom.size.height)
                        .background(
                            Color.groupedBackground.edgesIgnoringSafeArea([
                                .bottom, .horizontal,
                            ])
                        )
                        .transition(gridModel.animateDetailTransitions ? .flipFromRight : .identity)
                    }

                    if let tabGroupDetails = tabGroupModel.detailedTabGroup {
                        DetailView(primitive: tabGroupDetails) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                detailDragOffset = geom.size.width
                            }
                        }
                        .frame(width: geom.size.width, height: geom.size.height)
                        .background(
                            Color.groupedBackground.edgesIgnoringSafeArea([
                                .bottom, .horizontal,
                            ])
                        )
                        .transition(gridModel.animateDetailTransitions ? .flipFromRight : .identity)
                        .environment(\.cardSize, cardSize)
                        .environment(\.columns, columns)
                    }
                }.modifier(
                    DraggableDetail(
                        detailDragOffset: $detailDragOffset,
                        width: geom.size.width))
            }
            .useEffect(
                deps: geom.size.width, topToolbar, perform: updateCardSize
            )
        }
        .ignoresSafeArea(.keyboard)
        .accessibilityAction(.escape) {
            gridModel.hideWithAnimation()
        }
        .runAfter(
            toggling: gridModel.isHidden,
            fromTrueToFalse: {  // Done with animation to show the CardGrid
                gridModel.animationThumbnailState = .hidden
                gridModel.animateDetailTransitions = true
            },
            fromFalseToTrue: {  // Done with animation to hide the CardGrid
                gridModel.hideWithNoAnimation()
                gridModel.animateDetailTransitions = false
                tabGroupModel.detailedTabGroup = nil
            }
        )
        .useEffect(deps: gridModel.animationThumbnailState) { _ in
            // Ensure that the `Card` for the selected tab is visible. This way its
            // `CardTransitionModifier` will kick-in and run the animation and
            // toggle `gridModel.isHidden`. Update directly if there are no tabs.
            if gridModel.animationThumbnailState != .hidden {
                if tabModel.allDetails.isEmpty {
                    withAnimation {
                        gridModel.isHidden =
                            (gridModel.animationThumbnailState == .visibleForTrayHidden)
                    }
                } else {
                    gridModel.scrollToSelectedTab()
                }
            }
        }
    }
}

private struct DraggableDetail: ViewModifier {
    static let Threshold: CGFloat = 100
    static let DraggableWidth: CGFloat = 50
    @Binding var detailDragOffset: CGFloat
    let width: CGFloat
    @EnvironmentObject var spaceModel: SpaceCardModel
    @EnvironmentObject var tabGroupModel: TabGroupCardModel

    func body(content: Content) -> some View {
        content
            .offset(x: detailDragOffset, y: 0)
            .runAfter(
                toggling: detailDragOffset == width, fromTrueToFalse: {},
                fromFalseToTrue: {
                    spaceModel.detailedSpace = nil
                    tabGroupModel.detailedTabGroup = nil
                    detailDragOffset = 0
                }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: DraggableDetail.DraggableWidth)
                    .onChanged { value in
                        if detailDragOffset != 0
                            || (value.startLocation.x < DraggableDetail.DraggableWidth
                                && value.translation.width > 0
                                && abs(value.translation.width)
                                    > abs(value.translation.height))
                        {
                            detailDragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        withAnimation(.easeInOut(duration: 0.4)) {
                            if abs(detailDragOffset) > DraggableDetail.Threshold {
                                detailDragOffset = width
                            } else {
                                detailDragOffset = 0
                            }
                        }
                    }
            )
    }
}

struct GridPicker: View {
    @EnvironmentObject var gridModel: GridModel
    @EnvironmentObject var tabModel: TabCardModel

    var body: some View {
        Picker("", selection: $gridModel.switcherState) {
            ForEach(SwitcherViews.allCases, id: \.rawValue) { view in
                Text(view.rawValue).tag(view)
            }
        }.pickerStyle(SegmentedPickerStyle())
            .padding(CardGridUX.PickerPadding)
            .disabled(tabModel.manager.isIncognito)
            .frame(height: gridModel.pickerHeight)
            .background(Color.DefaultBackground)
            .opacity(gridModel.isHidden ? 0 : 1)
            .animation(.easeOut)
    }
}

struct SwipeToSwitchToSpacesGesture: ViewModifier {
    let gridModel: GridModel
    let tabModel: TabCardModel

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .global)
                    .onEnded { value in
                        let horizontalAmount = value.translation.width as CGFloat
                        let verticalAmount = value.translation.height as CGFloat

                        if abs(horizontalAmount) > abs(verticalAmount)
                            && !tabModel.manager.isIncognito
                        {
                            gridModel.switcherState = horizontalAmount < 0 ? .spaces : .tabs
                        }
                    })
    }
}
