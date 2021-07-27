// Copyright Neeva. All rights reserved.

import Combine
import SwiftUI

// Optionally wraps an embedded view with a ScrollView based on a specified
// threshold height value. I.e., if the view needs to be larger than the
// specified value, then a ScrollView will be inserted.
public struct VerticalScrollViewIfNeeded<EmbeddedView>: View where EmbeddedView: View {
    let embeddedView: () -> EmbeddedView

    @State var viewHeight: CGFloat = 0

    public var body: some View {
        GeometryReader { parentGeom in
            let content = embeddedView()
                .background(GeometryReader { contentGeom in
                    Color.clear
                        .allowsHitTesting(false)
                        .useEffect(deps: contentGeom.size.height) {
                            viewHeight = $0
                        }
                })
            if parentGeom.size.height < viewHeight {
                ScrollView {
                    content
                }
            } else {
                content
            }
        }
    }
}

// Detect if the keyboard is visible or not and publish that state.
// It can then be read via .onReceive on a View.
// From https://stackoverflow.com/questions/65784294/how-to-detect-if-keyboard-is-present-in-swiftui
// See also https://www.vadimbulavin.com/how-to-move-swiftui-view-when-keyboard-covers-text-field/
protocol KeyboardReadable {
    var keyboardPublisher: AnyPublisher<CGFloat, Never> { get }
}
extension KeyboardReadable {
    var keyboardPublisher: AnyPublisher<CGFloat, Never> {
        Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .map { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0 },

            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in 0 }
        )
        .eraseToAnyPublisher()
    }
}

// Used to observe / read the preference value that we store.
struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = value + nextValue()
    }
}

// Used to extract the intrinsic size of the content and store it as
// a preference value.
extension ViewHeightKey: ViewModifier {
    func body(content: Content) -> some View {
        return content.background(GeometryReader { proxy in
            Color.clear.preference(key: Self.self, value: proxy.size.height)
        })
    }
}
