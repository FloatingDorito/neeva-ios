// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Defaults
import Shared
import SwiftUI

extension BrowserViewController {
    func showQuestNeevaMenuPrompt() {
        guard TourManager.shared.hasActiveStep() else { return }
        var target: UIView

        scrollController?.showToolbars(animated: true)

        if !self.chromeModel.inlineToolbar, let toolbar = toolbar {
            // TODO(jed): open this prompt from SwiftUI once we have a full-height SwiftUI hierarchy
            target = toolbar.view
        } else {
            chromeModel.showNeevaMenuTourPrompt = true
            return
        }

        // Duplicated in TopBarNeevaMenuButton
        let content = TourPromptContent(
            title: "Get the most out of Neeva!",
            description: "Access your Neeva Home, Spaces, Settings, and more",
            buttonMessage: "Let's take a Look!",
            onButtonClick: {
                SceneDelegate.getBVC(for: self.view).showNeevaMenuSheet()

            },
            onClose: { [self] in
                // Duplicated in TopBarNeevaMenuButton
                self.dismiss(animated: true, completion: nil)
                TourManager.shared.responseMessage(
                    for: TourManager.shared.getActiveStepName(), exit: true)
            })

        let prompt = TourPromptViewController(delegate: self, source: target, content: content)

        prompt.view.backgroundColor = UIColor.Tour.Background.lightVariant
        prompt.preferredContentSize = prompt.sizeThatFits(in: CGSize(width: 300, height: 190))

        if self.presentedViewController == nil {
            present(prompt, animated: true, completion: nil)
        }
    }
}
