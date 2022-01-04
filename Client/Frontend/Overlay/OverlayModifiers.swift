// Copyright Neeva. All rights reserved.

import SwiftUI

// This PreferenceKey may be used by a child View of the OverlayView (i.e., PopoverView or OverlaySheetView)
// to specify a title for the sheet.
//
// E.g.:
//
//    PopoverView(..) {
//        SomeContent()
//            .overlayTitle(title: "Some Title")
//    }
//
struct OverlayTitlePreferenceKey: PreferenceKey {
    static var defaultValue: LocalizedStringKey? = nil
    static func reduce(value: inout LocalizedStringKey?, nextValue: () -> LocalizedStringKey?) {
        value = nextValue()
    }
}

struct OverlayTitleViewModifier: ViewModifier {
    let title: LocalizedStringKey
    func body(content: Content) -> some View {
        content.preference(
            key: OverlayTitlePreferenceKey.self,
            value: title)
    }
}

extension View {
    func overlayTitle(title: LocalizedStringKey) -> some View {
        self.modifier(OverlayTitleViewModifier(title: title))
    }
}

// This PreferenceKey may be used by a child View of the OverlayView
// to specify that the content should be treated as fixed height.
struct OverlayIsFixedHeightPreferenceKey: PreferenceKey {
    typealias Value = Bool
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}

struct OverlayIsFixedHeightViewModifier: ViewModifier {
    let isFixedHeight: Bool
    func body(content: Content) -> some View {
        content.preference(
            key: OverlayIsFixedHeightPreferenceKey.self,
            value: isFixedHeight)
    }
}

extension View {
    func overlayIsFixedHeight(isFixedHeight: Bool) -> some View {
        self.modifier(OverlayIsFixedHeightViewModifier(isFixedHeight: isFixedHeight))
    }
}
