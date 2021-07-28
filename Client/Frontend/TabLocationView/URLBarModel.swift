// Copyright Neeva. All rights reserved.

import Combine
import Foundation
import SwiftUI

class URLBarModel: ObservableObject {
    enum ReloadButtonState: String {
        case reload = "Reload"
        case stop = "Stop"
    }

    @Published var url: URL?
    /// `true` iff all assets on the page are secure (i.e. there is no mixed content)
    @Published var isSecure = false
    @Published var hasCertError = false

    @Published var showToolbarItems = false

    @Published private(set) var isEditing = false

    @Published var reloadButton = ReloadButtonState.reload
    @Published var readerMode = ReaderModeState.unavailable
    @Published var canShare = false
    @Published var includeShareButtonInLocationView = true

    @Published var estimatedProgress: Double?

    func setEditing(to value: Bool) {
        withAnimation(TabLocationViewUX.animation.delay(0.08)) {
            isEditing = value
        }
    }

    init() {}
    init(previewURL: URL?, isSecure: Bool) {
        self.url = previewURL
        self.isSecure = isSecure
    }
}
