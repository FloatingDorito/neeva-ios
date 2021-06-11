/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared

public enum SimpleToastUX {
    static let ToastHeight = BottomToolbarHeight
    static let ToastAnimationDuration = 0.5
    static let ToastDefaultColor = UIColor.Photon.Grey60
    fileprivate static let ToastFont = UIFont.systemFont(ofSize: 14, weight: .light)
    static let ToastDismissAfter = DispatchTimeInterval.milliseconds(4500) // 4.5 seconds.
    static let ToastDelayBefore = DispatchTimeInterval.milliseconds(0) // 0 seconds
    fileprivate static let ToastPrivateModeDelayBefore = DispatchTimeInterval.milliseconds(750)
    fileprivate static let BottomToolbarHeight = CGFloat(45)
    static let ToastCornerRadius: CGFloat = 15.0
}

struct SimpleToast {
    func showAlertWithText(_ text: String, bottomContainer: UIView) {
        let toast = self.createView()
        toast.text = text
        toast.layer.cornerRadius = SimpleToastUX.ToastCornerRadius
        bottomContainer.addSubview(toast)
        toast.snp.makeConstraints { (make) in
            make.width.equalTo(bottomContainer).offset(-16)
            make.left.equalTo(bottomContainer).offset(8)
            make.height.equalTo(SimpleToastUX.ToastHeight)
            make.bottom.equalTo(bottomContainer).offset(-8)
        }
        animate(toast)
    }

    fileprivate func createView() -> UILabel {
        let toast = UILabel()
        toast.textColor = UIColor.Photon.White100
        toast.backgroundColor = SimpleToastUX.ToastDefaultColor
        toast.font = SimpleToastUX.ToastFont
        toast.textAlignment = .center
        return toast
    }

    fileprivate func dismiss(_ toast: UIView) {
        UIView.animate(withDuration: SimpleToastUX.ToastAnimationDuration,
            animations: {
                var frame = toast.frame
                frame.origin.y = frame.origin.y + SimpleToastUX.ToastHeight
                frame.size.height = 0
                toast.frame = frame
            },
            completion: { finished in
                toast.removeFromSuperview()
            }
        )
    }

    fileprivate func animate(_ toast: UIView) {
        UIView.animate(withDuration: SimpleToastUX.ToastAnimationDuration,
            animations: {
                var frame = toast.frame
                frame.origin.y = frame.origin.y - SimpleToastUX.ToastHeight
                frame.size.height = SimpleToastUX.ToastHeight
                toast.frame = frame
            },
            completion: { finished in
                let dispatchTime = DispatchTime.now() + SimpleToastUX.ToastDismissAfter

                DispatchQueue.main.asyncAfter(deadline: dispatchTime, execute: {
                    self.dismiss(toast)
                })
            }
        )
    }
}
