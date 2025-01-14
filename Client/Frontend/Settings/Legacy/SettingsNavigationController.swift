/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

class ThemedNavigationController: UINavigationController {
    var presentingModalViewControllerDelegate: PresentingModalViewControllerDelegate?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return topViewController?.preferredStatusBarStyle ?? ThemeManager.instance.statusBarStyle
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationStyle = .formSheet
        modalPresentationCapturesStatusBarAppearance = true
        applyTheme()
    }
}

extension ThemedNavigationController: Themeable {
    func applyTheme() {
        navigationBar.barTintColor = UIColor.theme.tableView.headerBackground
        navigationBar.tintColor = .ui.adaptive.blue
        navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.headerTextDark
        ]
        setNeedsStatusBarAppearanceUpdate()
        viewControllers.forEach {
            ($0 as? Themeable)?.applyTheme()
        }
    }
}

protocol PresentingModalViewControllerDelegate: AnyObject {
    func dismissPresentedModalViewController(
        _ modalViewController: UIViewController, animated: Bool)
}
