// Copyright Neeva. All rights reserved.

import SDWebImageSwiftUI
import SFSafeSymbols
import Shared
import SwiftUI

struct TabToolbarButton<Content: View>: View {
    let label: Content
    let action: () -> Void
    let longPressAction: (() -> Void)?

    @Environment(\.isEnabled) private var isEnabled

    public init(
        label: Content,
        action: @escaping () -> Void,
        longPressAction: (() -> Void)? = nil
    ) {
        self.label = label
        self.action = action
        self.longPressAction = longPressAction
    }

    var body: some View {
        LongPressButton(action: action, longPressAction: longPressAction) {
            Spacer(minLength: 0)
            label.tapTargetFrame()
            Spacer(minLength: 0)
        }
        .accentColor(isEnabled ? .label : .quaternaryLabel)
    }
}

enum TabToolbarButtons {
    struct BackButton: View {
        let weight: Font.Weight
        let onBack: () -> Void
        let onLongPress: () -> Void

        @EnvironmentObject private var model: TabChromeModel
        var body: some View {
            Group {
                TabToolbarButton(
                    label: Symbol(
                        .arrowBackward, size: 20, weight: weight,
                        label: .TabToolbarBackAccessibilityLabel),
                    action: onBack,
                    longPressAction: onLongPress
                )
                .disabled(!model.canGoBack)
            }
        }
    }

    struct ForwardButton: View {
        let weight: Font.Weight
        let onForward: () -> Void
        let onLongPress: () -> Void

        @EnvironmentObject private var model: TabChromeModel

        var body: some View {
            Group {
                TabToolbarButton(
                    label: Symbol(
                        .arrowForward, size: 20, weight: weight,
                        label: .TabToolbarForwardAccessibilityLabel),
                    action: onForward,
                    longPressAction: onLongPress
                )
                .disabled(!model.canGoForward)
            }
        }
    }

    struct ReloadStopButton: View {
        let weight: Font.Weight
        let onTap: () -> Void

        @EnvironmentObject private var model: TabChromeModel

        var body: some View {
            Group {
                TabToolbarButton(
                    label: Symbol(
                        model.reloadButton == .reload ? .arrowClockwise : .xmark, size: 20,
                        weight: weight,
                        label: model.reloadButton == .reload ? "Reload" : "Stop"),
                    action: onTap
                )
            }
        }
    }

    struct OverflowMenu: View {
        let weight: Font.Weight
        let action: () -> Void
        let onLongPress: () -> Void

        @Environment(\.isIncognito) private var isIncognito

        var body: some View {
            TabToolbarButton(
                label: Symbol(
                    .ellipsisCircle,
                    size: 20, weight: weight,
                    label: .TabToolbarMoreAccessibilityLabel),
                action: action,
                longPressAction: onLongPress
            )
        }
    }

    struct NeevaMenu: View {
        let iconWidth: CGFloat
        let action: () -> Void

        @Environment(\.isIncognito) private var isIncognito

        var body: some View {
            TabToolbarButton(
                label: Image("neevaMenuIcon")
                    .renderingMode(isIncognito ? .template : .original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconWidth)
                    .accessibilityLabel("Neeva Menu"),
                action: action
            )
        }
    }

    struct AddToSpace: View {
        let weight: NiconFont
        let action: () -> Void

        @Environment(\.isIncognito) private var isIncognito
        @EnvironmentObject private var model: TabChromeModel

        var body: some View {
            TabToolbarButton(
                label: Symbol(
                    model.urlInSpace ? .bookmarkFill : .bookmark,
                    size: 20, weight: weight, label: "Add To Space"),
                action: action
            )
            .disabled(isIncognito || !model.isPage)
        }
    }

    struct ShowTabs: View {
        let weight: UIImage.SymbolWeight
        let action: () -> Void
        let buildMenu: () -> UIMenu?

        var body: some View {
            SecondaryMenuButton(action: action) {
                $0.setImage(Symbol.uiImage(.squareOnSquare, size: 20, weight: weight), for: .normal)
                $0.setDynamicMenu(buildMenu)
                $0.accessibilityLabel = "Show Tabs"
            }
        }
    }

    struct ShareButton: View {
        let weight: Font.Weight
        let action: () -> Void

        var body: some View {
            TabToolbarButton(
                label: Symbol(
                    .squareAndArrowUp,
                    size: 20, weight: weight,
                    label: "share"),
                action: action
            )
        }
    }

    struct ShowPreferenceButton: View {
        let weight: Font.Weight
        let action: () -> Void

        @EnvironmentObject private var model: TabChromeModel

        var body: some View {
            if let faviconURL = model.currentCheatsheetFaviconURL {
                TabToolbarButton(
                    label: WebImage(url: faviconURL)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                        .cornerRadius(6),
                    action: action
                )
            } else if let currentURLInitial = model.currentCheatsheetURL?.baseDomain?.asURL?.absoluteString.first?.description {
                TabToolbarButton(
                    label: Circle()
                        .fill(Color.gray)
                        .overlay(Text(currentURLInitial).foregroundColor(Color.brand.white).padding(.bottom, 2))
                        .frame(width: 24, height: 24),
                    action: action
                )
            } else {
                TabToolbarButton(
                    label: Circle()
                        .fill(Color.gray)
                        .frame(width: 24, height: 24),
                    action: action
                )
            }
        }
    }
}
