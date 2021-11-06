// Copyright Neeva. All rights reserved.

import Defaults
import Shared
import SwiftUI

class SearchBarTourPromptViewController: UIHostingController<TourPromptView> {

    var delegate: BrowserViewController?

    public init(delegate: BrowserViewController, source: UIView) {
        super.init(
            rootView: TourPromptView(
                title: "Search with Neeva!",
                description: "Search right from the address bar, anywhere, anytime",
                buttonMessage: "Got it!"))
        self.delegate = delegate
        self.modalPresentationStyle = .popover
        self.rootView.onConfirm = self.onDismiss

        let popoverViewController = self.popoverPresentationController
        popoverViewController?.permittedArrowDirections = .up
        popoverViewController?.delegate = delegate
        popoverViewController?.sourceView = source
    }

    func onDismiss() {
        self.dismiss(animated: true, completion: nil)
        Defaults[.searchInputPromptDismissed] = true
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
