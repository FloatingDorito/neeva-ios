/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared
import Storage
import Defaults

protocol PhotonActionSheetProtocol {
    var tabManager: TabManager { get }
    var profile: Profile { get }
}

extension PhotonActionSheetProtocol {
    typealias PresentableVC = UIViewController & UIPopoverPresentationControllerDelegate
    typealias MenuAction = () -> Void
    typealias IsPrivateTab = Bool
    typealias URLOpenAction = (URL?, IsPrivateTab) -> Void

    func presentSheetWith(title: String? = nil, actions: [[PhotonActionSheetItem]], on viewController: PresentableVC, from view: UIView, closeButtonTitle: String = Strings.CloseButtonTitle, suppressPopover: Bool = false) {
        let style: UIModalPresentationStyle = (UIDevice.current.userInterfaceIdiom == .pad && !suppressPopover) ? .popover : .overCurrentContext
        let sheet = PhotonActionSheet(title: title, actions: actions, closeButtonTitle: closeButtonTitle, style: style)
        sheet.modalPresentationStyle = style
        sheet.photonTransitionDelegate = PhotonActionSheetAnimator()

        if let popoverVC = sheet.popoverPresentationController, sheet.modalPresentationStyle == .popover {
            popoverVC.delegate = viewController
            popoverVC.sourceView = view
            popoverVC.sourceRect = CGRect(x: view.frame.width/2, y: view.frame.size.height * 0.75, width: 1, height: 1)
            popoverVC.permittedArrowDirections = .up
        }
        viewController.present(sheet, animated: true, completion: nil)
    }

    func getLegacyLongPressLocationBarActions(with urlBar: LegacyURLBarView, webViewContainer: UIView) -> [PhotonActionSheetItem] {
        let pasteGoAction = PhotonActionSheetItem(title: Strings.PasteAndGoTitle, iconString: "doc.on.clipboard", iconType: .SystemImage, iconAlignment: .right) { _, _ in
            if let pasteboardContents = UIPasteboard.general.string {
                urlBar.delegate?.urlBar(didSubmitText: pasteboardContents)
            }
        }
        let pasteAction = PhotonActionSheetItem(title: Strings.PasteTitle, iconString: "doc.on.clipboard.fill", iconType: .SystemImage, iconAlignment: .right) { _, _ in
            if let pasteboardContents = UIPasteboard.general.string {
                urlBar.enterOverlayMode(pasteboardContents, pasted: true, search: true)
            }
        }
        let copyAddressAction = PhotonActionSheetItem(title: Strings.CopyAddressTitle, iconString: "link", iconType: .SystemImage, iconAlignment: .right) { _, _ in
            if let url = self.tabManager.selectedTab?.canonicalURL?.displayURL ?? urlBar.model.url {
                UIPasteboard.general.url = url

                if !FeatureFlag[.useOldToast] {
                    let toastView = ToastViewManager.shared.makeToast(text: Strings.AppMenuCopyURLConfirmMessage)
                    ToastViewManager.shared.enqueue(toast: toastView)
                } else {
                    SimpleToast().showAlertWithText(Strings.AppMenuCopyURLConfirmMessage, bottomContainer: webViewContainer)
                }
            }
        }
        if UIPasteboard.general.string != nil {
            return [pasteGoAction, pasteAction, copyAddressAction]
        } else {
            return [copyAddressAction]
        }
    }

    func toggleDesktopSiteAction(for tab: Tab) -> UIAction {

        let defaultUAisDesktop = UserAgent.isDesktop(ua: UserAgent.getUserAgent())
        let hasHomeButton = UIApplication.shared.keyWindow?.safeAreaInsets.bottom == 0
                let mobileIcon = hasHomeButton ? "iphone.homebutton" : "iphone"
        let toggleActionTitle: String
        let iconName: String
        if defaultUAisDesktop {
            toggleActionTitle = tab.changedUserAgent ? Strings.AppMenuViewDesktopSiteTitleString : Strings.AppMenuViewMobileSiteTitleString
            iconName = tab.changedUserAgent ? "laptopcomputer" : mobileIcon
        } else {
            toggleActionTitle = tab.changedUserAgent ? Strings.AppMenuViewMobileSiteTitleString : Strings.AppMenuViewDesktopSiteTitleString
            iconName = tab.changedUserAgent ? mobileIcon : "laptopcomputer"
        }
        return UIAction(title: toggleActionTitle, image: UIImage(systemName: iconName)) { _ in

            if let url = tab.url {
                tab.toggleChangeUserAgent()
                Tab.ChangeUserAgent.updateDomainList(forUrl: url, isChangedUA: tab.changedUserAgent, isPrivate: tab.isPrivate)
            }
        }
    }

    func getRefreshLongPressMenu(for tab: Tab) -> UIMenu? {
        guard tab.webView?.url != nil && (tab.getContentScript(name: ReaderMode.name()) as? ReaderMode)?.state != .active else {
            return nil
        }

        let toggleDesktopSite = toggleDesktopSiteAction(for: tab)
        return UIMenu(children: [toggleDesktopSite])
    }

}
