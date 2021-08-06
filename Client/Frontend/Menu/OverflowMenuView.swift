// Copyright Neeva. All rights reserved.

import SFSafeSymbols
import Shared
import SwiftUI

private enum OverflowMenuUX {
    static let innerSectionPadding: CGFloat = 8
    static let squareButtonSize: CGFloat = 83
    static let squareButtonSpacing: CGFloat = 4
    static let squareButtonIconSize: CGFloat = 20
}

public struct OverflowMenuButtonView: View {
    let label: String
    let symbol: SFSymbol
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    public init(label: String, symbol: SFSymbol, action: @escaping () -> Void) {
        self.label = label
        self.symbol = symbol
        self.action = action
    }

    public var body: some View {
        GroupedCellButton(action: action) {
            VStack(spacing: OverflowMenuUX.squareButtonSpacing) {
                Symbol(decorative: symbol, size: OverflowMenuUX.squareButtonIconSize)
                Text(label).withFont(.bodyLarge)
            }.frame(height: OverflowMenuUX.squareButtonSize)
        }
        .accentColor(isEnabled ? .label : .quaternaryLabel)
    }
}

public struct OverflowMenuView: View {
    private let menuAction: (OverflowMenuButtonActions) -> Void
    private let changedUserAgent: Bool

    @EnvironmentObject var tabToolBarModel: TabToolbarModel
    @EnvironmentObject var urlBarModel: URLBarModel

    public init(
        changedUserAgent: Bool = false,
        menuAction: @escaping (OverflowMenuButtonActions) -> Void
    ) {
        self.menuAction = menuAction
        self.changedUserAgent = changedUserAgent
    }

    public var body: some View {
        GroupedStack {
            HStack(spacing: OverflowMenuUX.innerSectionPadding) {
                OverflowMenuButtonView(label: "Forward", symbol: .arrowForward) {
                    menuAction(OverflowMenuButtonActions.forward)
                }
                .accessibilityIdentifier("OverflowMenu.Forward")
                .disabled(!tabToolBarModel.canGoForward)

                OverflowMenuButtonView(
                    label: urlBarModel.reloadButton == .reload ? "Reload" : "Stop",
                    symbol: urlBarModel.reloadButton == .reload ? .arrowClockwise : .xmark
                ) {
                    menuAction(OverflowMenuButtonActions.reload)
                }
                .accessibilityIdentifier("OverflowMenu.Reload")

                OverflowMenuButtonView(label: "New Tab", symbol: .plus) {
                    menuAction(OverflowMenuButtonActions.newTab)
                }
                .accessibilityIdentifier("OverflowMenu.NewTab")
            }

            GroupedCell.Decoration {
                VStack(spacing: 0) {
                    NeevaMenuRowButtonView(
                        label: "Find on Page",
                        symbol: .docTextMagnifyingglass
                    ) {
                        menuAction(OverflowMenuButtonActions.findOnPage)
                    }
                    .accessibilityIdentifier("OverflowMenu.FindOnPage")

                    Color.groupedBackground.frame(height: 1)

                    NeevaMenuRowButtonView(
                        label: "Text Size",
                        symbol: .textformatSize
                    ) {
                        menuAction(OverflowMenuButtonActions.textSize)
                    }
                    .accessibilityIdentifier("OverflowMenu.TextSize")

                    Color.groupedBackground.frame(height: 1)

                    let hasHomeButton = UIConstants.safeArea.bottom == 0
                    NeevaMenuRowButtonView(
                        label: changedUserAgent == true
                            ? Strings.AppMenuViewMobileSiteTitleString
                            : Strings.AppMenuViewDesktopSiteTitleString,
                        symbol: changedUserAgent == true
                            ? (hasHomeButton ? .iphoneHomebutton : .iphone)
                            : .desktopcomputer
                    ) {
                        menuAction(OverflowMenuButtonActions.desktopSite)
                    }
                    .accessibilityIdentifier("OverflowMenu.RequestDesktopSite")
                }
                .accentColor(.label)
            }
        }
    }
}

struct OverflowMenuView_Previews: PreviewProvider {
    static var previews: some View {
        OverflowMenuView(menuAction: { _ in }).previewDevice("iPod touch (7th generation)").environment(
            \.sizeCategory, .extraExtraExtraLarge)
        OverflowMenuView(menuAction: { _ in })
    }
}
