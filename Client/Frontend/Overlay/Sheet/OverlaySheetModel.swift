// Copyright Neeva. All rights reserved.

import SwiftUI

enum OverlaySheetPosition: LocalizedStringKey {
    case top = "Full screen"
    case middle = "Half screen"
    case dismissed = ""
}

class OverlaySheetModel: ObservableObject {
    @Published var topBarHeight: CGFloat = 0
    @Published var peekHeight: CGFloat = 0
    @Published var deltaHeight: CGFloat = 0
    @Published var position: OverlaySheetPosition = .dismissed
    @Published var backdropOpacity: Double = 0.0

    func show(defaultPosition: OverlaySheetPosition = .middle) {
        withAnimation(.easeOut(duration: OverlaySheetUX.animationDuration)) {
            self.position = defaultPosition
            self.backdropOpacity = peekHeight > 0 ? 0 : OverlaySheetUX.backdropMaxOpacity
        }
    }

    func hide() {
        withAnimation(.easeOut(duration: OverlaySheetUX.animationDuration)) {
            self.deltaHeight = 0
            self.position = .dismissed
            self.backdropOpacity = 0.0
        }
    }
}
