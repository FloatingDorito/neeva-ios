// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI

struct CardTransitionUX {
    static let animation = Animation.interpolatingSpring(stiffness: 425, damping: 30)
}

struct CardTransitionModifier<Details: CardDetails>: ViewModifier {
    let details: Details
    let containerGeometry: GeometryProxy
    var extraBottomPadding: CGFloat = 0

    @EnvironmentObject var browserModel: BrowserModel

    func body(content: Content) -> some View {
        content
            .zIndex(details.isSelected ? 1 : 0)
            .opacity(details.isSelected && browserModel.cardTransition != .hidden ? 0 : 1)
            .overlay(overlay)
    }

    var overlay: some View {
        GeometryReader { geom in
            if details.isSelected && browserModel.cardTransition != .hidden {
                let rect = calculateCardRect(geom: geom)
                overlayCard
                    .offset(x: rect.minX, y: rect.minY)
                    .frame(width: rect.width, height: rect.height)
                    .animation(CardTransitionUX.animation)
                    .transition(.identity)
            }
        }
        .ignoresSafeArea(edges: [.bottom])
        .accessibilityHidden(true)
    }

    @ViewBuilder var overlayCard: some View {
        if let tabGroupDetails = details as? TabGroupCardDetails {
            let selectedTabDetails = (tabGroupDetails.allDetails.first { $0.isSelected })!
            Card(details: selectedTabDetails, showsSelection: browserModel.showGrid, animate: true)
        } else {
            Card(details: details, showsSelection: browserModel.showGrid, animate: true)
        }
    }

    func calculateCardRect(geom: GeometryProxy) -> CGRect {
        if browserModel.showGrid {
            return geom.frame(in: .local)
        }

        let cardFrame = geom.frame(in: .global)
        let containerFrame = containerGeometry.frame(in: .global)

        let x = containerFrame.minX - cardFrame.minX
        let y = containerFrame.minY - cardFrame.minY
        let width = containerFrame.size.width
        let height = containerFrame.size.height - extraBottomPadding + CardUX.HeaderSize

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
