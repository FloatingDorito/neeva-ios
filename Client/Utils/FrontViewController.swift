// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import UIKit

extension UIViewController {
    /// The frontmost view controller. Used to present share sheets and other
    /// UIKit-only view controllers
    @objc var frontViewController: UIViewController {
        presentedViewController?.frontViewController ?? self
    }
}
extension UITabBarController {
    override var frontViewController: UIViewController {
        presentedViewController?.frontViewController ?? selectedViewController?.frontViewController
            ?? self
    }
}
extension UINavigationController {
    override var frontViewController: UIViewController {
        presentedViewController?.frontViewController ?? topViewController?.frontViewController
            ?? self
    }
}
extension UIWindowScene {
    var frontViewController: UIViewController? {
        windows.first?.rootViewController?.frontViewController
    }
}
