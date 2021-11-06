// Copyright Neeva. All rights reserved.

import Defaults
import Shared
import SwiftUI

struct TabLocationBarButton<Label: View>: View {
    let label: Label
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .frame(width: TabLocationViewUX.height, height: TabLocationViewUX.height)
                .transition(.opacity)
        }.foregroundColor(.label)
    }
}

struct LocationViewTrackingButton: View {
    @State private var showingPopover = false
    @Environment(\.isIncognito) private var isIncognito
    @EnvironmentObject private var trackingStatsModel: TrackingStatsViewModel

    let currentDomain: String

    var body: some View {
        let label =
            isIncognito
            ? Image("incognito", label: Text("Tracking Protection, Incognito"))
            : Image("tracking-protection", label: Text("Tracking Protection"))
        TabLocationBarButton(label: label.renderingMode(.template)) {
            ClientLogger.shared.logCounter(
                .OpenShield, attributes: EnvironmentHelper.shared.getAttributes())
            showingPopover = true
        }
        .presentAsPopover(
            isPresented: $showingPopover,
            backgroundColor: .systemGroupedBackground,
            arrowDirections: [.up, .down]
        ) {
            TrackingMenuView().environmentObject(trackingStatsModel)
        }
    }
}

struct LocationViewReloadButton: View {
    let buildMenu: () -> UIMenu?
    let state: TabChromeModel.ReloadButtonState
    let onTap: () -> Void

    var body: some View {
        // TODO: when dropping support for iOS 14, change this to a Menu view with a primaryAction
        SecondaryMenuButton(action: onTap) {
            $0.tintColor = .label
            $0.setImage(
                Symbol.uiImage(state == .reload ? .arrowClockwise : .xmark, weight: .medium),
                for: .normal)
            $0.accessibilityLabel =
                state == .reload
                ? .TabToolbarReloadAccessibilityLabel : .TabToolbarStopAccessibilityLabel
            $0.setDynamicMenu(buildMenu)
        }
        .frame(width: TabLocationViewUX.height, height: TabLocationViewUX.height)
    }
}

/// see also `TopBarShareButton`
struct LocationViewShareButton: View {
    let url: URL?
    let onTap: (UIView) -> Void

    @State private var shareTargetView: UIView!

    var body: some View {
        if url != nil {
            TabLocationBarButton(label: Symbol(.squareAndArrowUp, weight: .medium, label: "Share"))
            {
                onTap(shareTargetView)
            }
            .uiViewRef($shareTargetView)
        }
    }
}

struct TabLocationBarButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            LocationViewTrackingButton(currentDomain: "neeva.com")
            LocationViewTrackingButton(currentDomain: "neeva.com")
                .environment(\.isIncognito, true)
        }.previewLayout(.sizeThatFits)
        HStack {
            LocationViewReloadButton(
                buildMenu: { UIMenu(children: [UIAction(title: "Hello, world!") { _ in }]) },
                state: .reload
            ) {}
            LocationViewReloadButton(buildMenu: { nil }, state: .stop) {}
        }.previewLayout(.sizeThatFits)
        HStack {
            LocationViewShareButton(url: nil, onTap: { _ in })
            LocationViewShareButton(url: "https://neeva.com/", onTap: { _ in })
        }.previewLayout(.sizeThatFits)
    }
}
