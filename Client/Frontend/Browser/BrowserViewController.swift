/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Photos
import UIKit
import WebKit
import Shared
import Storage
import SnapKit
import XCGLogger
import MobileCoreServices
import SDWebImage
import SwiftyJSON
import SwiftUI
import Defaults

private let KVOs: [KVOConstants] = [
    .estimatedProgress,
    .loading,
    .canGoBack,
    .canGoForward,
    .URL,
    .title,
]

private let ActionSheetTitleMaxLength = 120

private enum BrowserViewControllerUX {
    static let ShowHeaderTapAreaHeight: CGFloat = 32
}

struct UrlToOpenModel {
    var url: URL?
    var isPrivate: Bool
}

/// Enum used to track flow for telemetry events
enum ReferringPage {
    case onboarding
    case appMenu
    case settings
    case none
}

class BrowserViewController: UIViewController {
    var neevaHomeViewController: NeevaHomeViewController?
    lazy var cardStripViewController: CardStripViewController? = {
        let controller = CardStripViewController(tabManager: self.tabManager)
        addChild(controller)
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        return controller
    }()
    var libraryViewController: LibraryViewController?
    var libraryDrawerViewController: DrawerViewController?
    var overlaySheetViewController: UIViewController?
    lazy var simulateForwardViewController: SimulatedSwipeController? = {
        let host = SimulatedSwipeController(tabManager: self.tabManager,
                                            navigationToolbar: navigationToolbar,
                                            swipeDirection: .forward)
        addChild(host)
        view.addSubview(host.view)
        host.view.isHidden = true
        return host
    }()
    lazy var simulateBackViewController: SimulatedSwipeController? = {
        let host = SimulatedSwipeController(tabManager: self.tabManager,
                                            navigationToolbar: navigationToolbar,
                                            swipeDirection: .back)
        addChild(host)
        view.addSubview(host.view)
        host.view.isHidden = true
        return host
    }()
    var webViewContainer: UIView!
    var legacyURLBar: LegacyURLBarView!
    var clipboardBarDisplayHandler: ClipboardBarDisplayHandler?
    var readerModeBar: ReaderModeBarView?
    var readerModeCache: ReaderModeCache
    var statusBarOverlay: UIView = UIView()
    fileprivate(set) var toolbar: TabToolbar?
    var searchController: SearchViewController?
    var screenshotHelper: ScreenshotHelper!
    fileprivate var homePanelIsInline = false
    var shouldSetUrlTypeSearch = false
    fileprivate var searchLoader: SearchLoader?
    let alertStackView = UIStackView() // All content that appears above the footer should be added to this view. (Find In Page/SnackBars)
    var findInPageBar: FindInPageBar?
    lazy var mailtoLinkHandler = MailtoLinkHandler()
    var urlFromAnotherApp: UrlToOpenModel?
    var isCrashAlertShowing: Bool = false
    fileprivate var customSearchBarButton: UIBarButtonItem?

    // popover rotation handling
    var displayedPopoverController: UIViewController?
    var updateDisplayedPopoverProperties: (() -> Void)?

    var openInHelper: OpenInHelper?

    // location label actions
    fileprivate var pasteGoAction: AccessibleAction!
    fileprivate var pasteAction: AccessibleAction!
    fileprivate var copyAddressAction: AccessibleAction!

    fileprivate weak var tabTrayController: TabTrayControllerV1?
    let profile: Profile
    let tabManager: TabManager

    // These views wrap the urlbar and toolbar to provide background effects on them
    var header: UIView!
    var footer: UIView!
    fileprivate var topTouchArea: UIButton!
    let urlBarTopTabsContainer = UIView(frame: CGRect.zero)
    var topTabsVisible: Bool {
        return topTabsViewController != nil
    }
    // Backdrop used for displaying greyed background for private tabs
    var webViewContainerBackdrop: UIView!

    var scrollController = TabScrollingController()

    fileprivate var keyboardState: KeyboardState?
    var hasTriedToPresentETPAlready = false
    var pendingToast: Toast? // A toast that might be waiting for BVC to appear before displaying
    var downloadToast: DownloadToast? // A toast that is showing the combined download progress

    // Tracking navigation items to record history types.
    // TODO: weak references?
    var ignoredNavigation = Set<WKNavigation>()
    var typedNavigation = [WKNavigation: VisitType]()
    var navigationToolbar: TabToolbarProtocol {
        return toolbar ?? legacyURLBar
    }

    var topTabsViewController: TopTabsViewController?
    let topTabsContainer = UIView()

    // Keep track of allowed `URLRequest`s from `webView(_:decidePolicyFor:decisionHandler:)` so
    // that we can obtain the originating `URLRequest` when a `URLResponse` is received. This will
    // allow us to re-trigger the `URLRequest` if the user requests a file to be downloaded.
    var pendingRequests = [String: URLRequest]()

    // This is set when the user taps "Download Link" from the context menu. We then force a
    // download of the next request through the `WKNavigationDelegate` that matches this web view.
    weak var pendingDownloadWebView: WKWebView?

    let downloadQueue = DownloadQueue()
    var isCmdClickForNewTab = false

    var isNeevaMenuSheetOpen = false
    var popOverNeevaMenuViewController: PopOverNeevaMenuViewController? = nil
    var isRotateSwitchDismiss = false // keep track whether a dismiss is trigger by rotation
    var isPreviousOrientationLandscape = false

    init(profile: Profile, tabManager: TabManager) {
        self.profile = profile
        self.tabManager = tabManager
        self.readerModeCache = DiskReaderModeCache.sharedInstance
        super.init(nibName: nil, bundle: nil)
        didInit()
        self.isPreviousOrientationLandscape = UIWindow.isLandscape
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var prefersStatusBarHidden: Bool {
        return false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        dismissVisibleMenus()

        coordinator.animate(alongsideTransition: { context in
            self.scrollController.updateMinimumZoom()
            self.topTabsViewController?.scrollToCurrentTab(false, centerCell: false)

            if let popover = self.displayedPopoverController {
                self.updateDisplayedPopoverProperties?()
                self.present(popover, animated: true, completion: nil)
            }

            if self.isNeevaMenuSheetOpen {
                if !(self.legacyURLBar.toolbarIsShowing && self.isPreviousOrientationLandscape) {
                    if self.legacyURLBar.toolbarIsShowing {
                        self.hideNeevaMenuSheet()
                        self.legacyURLBar.didClickNeevaMenu()
                    } else {
                        self.isRotateSwitchDismiss = true
                        self.popOverNeevaMenuViewController?.dismiss(animated: true, completion: nil)
                        self.showNeevaMenuSheet()
                    }
                }
            }
            self.isPreviousOrientationLandscape = UIWindow.isLandscape
        }, completion: { _ in
            self.scrollController.setMinimumZoom()
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    fileprivate func didInit() {
        screenshotHelper = ScreenshotHelper(controller: self)
        tabManager.addDelegate(self)
        tabManager.addNavigationDelegate(self)
        downloadQueue.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(displayThemeChanged), name: .DisplayThemeChanged, object: nil)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        guard legacyURLBar != nil else {
            return ThemeManager.instance.statusBarStyle
        }
        
        // top-tabs are always dark, so special-case this to light
        if legacyURLBar.topTabsIsShowing {
            return .lightContent
        } else {
            return ThemeManager.instance.statusBarStyle
        }
    }

    @objc func displayThemeChanged(notification: Notification) {
        applyTheme()
    }

    func shouldShowFooterForTraitCollection(_ previousTraitCollection: UITraitCollection) -> Bool {
        return previousTraitCollection.verticalSizeClass != .compact && previousTraitCollection.horizontalSizeClass != .regular
    }

    func shouldShowTopTabsForTraitCollection(_ newTraitCollection: UITraitCollection) -> Bool {
        return !FeatureFlag[.cardStrip] && newTraitCollection.verticalSizeClass == .regular && newTraitCollection.horizontalSizeClass == .regular
    }

    func toggleSnackBarVisibility(show: Bool) {
        if show {
            UIView.animate(withDuration: 0.1, animations: { self.alertStackView.isHidden = false })
        } else {
            alertStackView.isHidden = true
        }
    }

    fileprivate func constraintsForLibraryDrawerView(_ make: SnapKit.ConstraintMaker) {
        guard libraryDrawerViewController?.view.superview != nil else { return }
        if self.topTabsVisible {
            make.top.equalTo(webViewContainer)
        } else {
            make.top.equalTo(view)
        }

        make.right.bottom.left.equalToSuperview()
    }

    func updateToolbarStateForTraitCollection(_ newCollection: UITraitCollection, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator? = nil) {
        let showToolbar = shouldShowFooterForTraitCollection(newCollection)
        let showTopTabs = shouldShowTopTabsForTraitCollection(newCollection)
        
        legacyURLBar.topTabsIsShowing = showTopTabs
        legacyURLBar.setShowToolbar(!showToolbar)

        toolbar?.removeFromSuperview()
        toolbar?.tabToolbarDelegate = nil
        toolbar = nil

        if showToolbar {
            toolbar = TabToolbar()
            footer.addSubview(toolbar!)
            toolbar?.tabToolbarDelegate = self
        }

        if showTopTabs {
            if topTabsViewController == nil {
                let topTabsViewController = TopTabsViewController(tabManager: tabManager)
                topTabsViewController.delegate = self
                addChild(topTabsViewController)
                topTabsViewController.view.frame = topTabsContainer.frame
                topTabsContainer.addSubview(topTabsViewController.view)
                topTabsViewController.view.snp.makeConstraints { make in
                    make.edges.equalTo(topTabsContainer)
                    make.height.equalTo(TopTabsUX.TopTabsViewHeight)
                }
                self.topTabsViewController = topTabsViewController
            }
            topTabsContainer.snp.updateConstraints { make in
                make.height.equalTo(TopTabsUX.TopTabsViewHeight)
            }
        } else {
            topTabsContainer.snp.updateConstraints { make in
                make.height.equalTo(0)
            }
            topTabsViewController?.view.removeFromSuperview()
            topTabsViewController?.removeFromParent()
            topTabsViewController = nil
        }

        view.setNeedsUpdateConstraints()
        neevaHomeViewController?.view.setNeedsUpdateConstraints()

        if let tab = tabManager.selectedTab,
               let webView = tab.webView {
            toolbar?.applyUIMode(isPrivate: tab.isPrivate)
            updateURLBarDisplayURL(tab)
            navigationToolbar.updateBackStatus(webView.canGoBack)
            navigationToolbar.updateForwardStatus(webView.canGoForward)
        }

        libraryDrawerViewController?.view.snp.remakeConstraints(constraintsForLibraryDrawerView)
    }

    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)

        // During split screen launching on iPad, this callback gets fired before viewDidLoad gets a chance to
        // set things up. Make sure to only update the toolbar state if the view is ready for it.
        if isViewLoaded {
            updateToolbarStateForTraitCollection(newCollection, withTransitionCoordinator: coordinator)
        }

        displayedPopoverController?.dismiss(animated: true, completion: nil)
        coordinator.animate(alongsideTransition: { context in
            self.scrollController.showToolbars(animated: false)
            if self.isViewLoaded {
                self.statusBarOverlay.backgroundColor = self.shouldShowTopTabsForTraitCollection(self.traitCollection) ? UIColor.Photon.Grey80 : self.legacyURLBar.backgroundColor
                self.setNeedsStatusBarAppearanceUpdate()
            }
            }, completion: nil)
    }

    func dismissVisibleMenus() {
        displayedPopoverController?.dismiss(animated: true)
        if let _ = self.presentedViewController as? PhotonActionSheet {
            self.presentedViewController?.dismiss(animated: true, completion: nil)
        }
    }

    @objc func appDidEnterBackgroundNotification() {
        displayedPopoverController?.dismiss(animated: false) {
            self.updateDisplayedPopoverProperties = nil
            self.displayedPopoverController = nil
        }
    }

    @objc func tappedTopArea() {
        scrollController.showToolbars(animated: true)
    }

   @objc  func appWillResignActiveNotification() {
        // Dismiss any popovers that might be visible
        displayedPopoverController?.dismiss(animated: false) {
            self.updateDisplayedPopoverProperties = nil
            self.displayedPopoverController = nil
        }

        // If we are displying a private tab, hide any elements in the tab that we wouldn't want shown
        // when the app is in the home switcher
        guard let privateTab = tabManager.selectedTab, privateTab.isPrivate else {
            return
        }

        view.bringSubviewToFront(webViewContainerBackdrop)
        webViewContainerBackdrop.alpha = 1
        webViewContainer.alpha = 0
        legacyURLBar.locationContainer.alpha = 0
        neevaHomeViewController?.view.alpha = 0
        topTabsViewController?.switchForegroundStatus(isInForeground: false)
        presentedViewController?.popoverPresentationController?.containerView?.alpha = 0
        presentedViewController?.view.alpha = 0
    }

    @objc func appDidBecomeActiveNotification() {
        // Re-show any components that might have been hidden because they were being displayed
        // as part of a private mode tab
        UIView.animate(withDuration: 0.2, delay: 0, options: UIView.AnimationOptions(), animations: {
            self.webViewContainer.alpha = 1
            self.legacyURLBar.locationContainer.alpha = 1
            self.neevaHomeViewController?.view.alpha = 1
            self.topTabsViewController?.switchForegroundStatus(isInForeground: true)
            self.presentedViewController?.popoverPresentationController?.containerView?.alpha = 1
            self.presentedViewController?.view.alpha = 1
            self.view.backgroundColor = UIColor.clear
        }, completion: { _ in
            self.webViewContainerBackdrop.alpha = 0
            self.view.sendSubviewToBack(self.webViewContainerBackdrop)
        })

        // Re-show toolbar which might have been hidden during scrolling (prior to app moving into the background)
        scrollController.showToolbars(animated: false)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActiveNotification), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActiveNotification), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackgroundNotification), name: UIApplication.didEnterBackgroundNotification, object: nil)
        KeyboardHelper.defaultHelper.addDelegate(self)

        webViewContainerBackdrop = UIView()
        webViewContainerBackdrop.backgroundColor = UIColor.Photon.Ink90
        webViewContainerBackdrop.alpha = 0
        view.addSubview(webViewContainerBackdrop)

        webViewContainer = UIView()
        view.addSubview(webViewContainer)

        // Temporary work around for covering the non-clipped web view content
        statusBarOverlay = UIView()
        view.addSubview(statusBarOverlay)

        topTouchArea = UIButton()
        topTouchArea.isAccessibilityElement = false
        topTouchArea.addTarget(self, action: #selector(tappedTopArea), for: .touchUpInside)
        view.addSubview(topTouchArea)

        // Setup the URL bar, wrapped in a view to get transparency effect
        legacyURLBar = LegacyURLBarView(profile: profile)
        legacyURLBar.translatesAutoresizingMaskIntoConstraints = false
        legacyURLBar.delegate = self
        legacyURLBar.tabToolbarDelegate = self
        header = urlBarTopTabsContainer
        urlBarTopTabsContainer.addSubview(legacyURLBar)
        urlBarTopTabsContainer.addSubview(topTabsContainer)
        view.addSubview(header)
        if FeatureFlag[.newURLBar] {
            addChild(legacyURLBar.locationView)
            legacyURLBar.locationView.didMove(toParent: self)
        }

        // UIAccessibilityCustomAction subclass holding an AccessibleAction instance does not work, thus unable to generate AccessibleActions and UIAccessibilityCustomActions "on-demand" and need to make them "persistent" e.g. by being stored in BVC
        pasteGoAction = AccessibleAction(name: Strings.PasteAndGoTitle, handler: { () -> Bool in
            if let pasteboardContents = UIPasteboard.general.string {
                self.urlBar(self.legacyURLBar, didSubmitText: pasteboardContents)
                return true
            }
            return false
        })
        pasteAction = AccessibleAction(name: Strings.PasteTitle, handler: { () -> Bool in
            if let pasteboardContents = UIPasteboard.general.string {
                // Enter overlay mode and make the search controller appear.
                self.legacyURLBar.enterOverlayMode(pasteboardContents, pasted: true, search: true)

                return true
            }
            return false
        })
        copyAddressAction = AccessibleAction(name: Strings.CopyAddressTitle, handler: { () -> Bool in
            if let url = self.tabManager.selectedTab?.canonicalURL?.displayURL ?? self.legacyURLBar.currentURL {
                UIPasteboard.general.url = url
            }
            return true
        })

        view.addSubview(alertStackView)
        footer = UIView()
        view.addSubview(footer)
        alertStackView.axis = .vertical
        alertStackView.alignment = .center

        clipboardBarDisplayHandler = ClipboardBarDisplayHandler(tabManager: tabManager)
        clipboardBarDisplayHandler?.delegate = self

        scrollController.urlBar = legacyURLBar
        scrollController.readerModeBar = readerModeBar
        scrollController.header = header
        scrollController.footer = footer
        scrollController.snackBars = alertStackView

        self.updateToolbarStateForTraitCollection(self.traitCollection)

        setupConstraints()

        // Setup UIDropInteraction to handle dragging and dropping
        // links into the view from other apps.
        let dropInteraction = UIDropInteraction(delegate: self)
        view.addInteraction(dropInteraction)

        if !Defaults[.nightModeStatus] {
            if #available(iOS 13.0, *) {
                if ThemeManager.instance.systemThemeIsOn {
                    let userInterfaceStyle = traitCollection.userInterfaceStyle
                    ThemeManager.instance.current = userInterfaceStyle == .dark ? DarkTheme() : NormalTheme()
                }
            }
        }
    }

    func showSearchBarPrompt() {
        // show tour prompt for search bar
        if Defaults[.searchInputPromptDismissed] || !NeevaUserInfo.shared.hasLoginCookie() {
            return
        }

        let prompt = SearchBarTourPromptViewController(delegate: self, source: self.legacyURLBar.legacyLocationView.urlLabel)
        prompt.view.backgroundColor = UIColor.neeva.Tour.Background
        prompt.preferredContentSize = prompt.sizeThatFits(in: CGSize(width: 260, height: 165))

        guard let currentViewController = navigationController?.topViewController else {
            return
        }

        if currentViewController is BrowserViewController {
            present(prompt, animated: true, completion: nil)
        }
    }

    fileprivate func setupConstraints() {
        topTabsContainer.snp.makeConstraints { make in
            make.leading.trailing.equalTo(self.header)
            make.top.equalTo(urlBarTopTabsContainer)
        }

        legacyURLBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalTo(urlBarTopTabsContainer)
            if legacyURLBar.toolbarIsShowing {
                make.height.equalTo(UIConstants.TopToolbarHeightWithToolbarButtonsShowing)
            } else {
                make.height.equalTo(UIConstants.TopToolbarHeight)
            }
            if FeatureFlag[.cardStrip] {
                make.top.equalTo(urlBarTopTabsContainer.snp.top)
            } else {
                make.top.equalTo(topTabsContainer.snp.bottom)
            }
        }

        header.snp.makeConstraints { make in
            scrollController.headerTopConstraint = make.top.equalTo(self.view.safeArea.top).constraint
            make.left.right.equalTo(self.view)
        }

        webViewContainerBackdrop.snp.makeConstraints { make in
            make.edges.equalTo(self.view)
        }

        if FeatureFlag[.cardStrip] {
            cardStripViewController?.view.snp.updateConstraints { make in
                make.left.right.equalTo(self.view)
                make.bottom.equalTo(self.view.snp.bottom).offset(-CardStripUX.BottomPadding)
                make.height.equalTo(CardStripUX.Height)
            }
        }

        if FeatureFlag[.swipePlusPlus] {
            simulateForwardViewController?.view.snp.makeConstraints { make in
                make.top.bottom.equalTo(webViewContainer)
                make.width.equalTo(webViewContainer).offset(SimulatedSwipeUX.EdgeWidth)
                make.leading.equalTo(webViewContainer.snp.trailing).offset(-SimulatedSwipeUX.EdgeWidth)
            }
        }

        simulateBackViewController?.view.snp.makeConstraints { make in
            make.top.bottom.equalTo(webViewContainer)
            make.width.equalTo(webViewContainer).offset(SimulatedSwipeUX.EdgeWidth)
            make.trailing.equalTo(webViewContainer.snp.leading).offset(SimulatedSwipeUX.EdgeWidth)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        statusBarOverlay.snp.remakeConstraints { make in
            make.top.left.right.equalTo(self.view)
            make.height.equalTo(self.view.safeAreaInsets.top)
        }
    }

    func loadQueuedTabs(receivedURLs: [URL]? = nil) {
        // Chain off of a trivial deferred in order to run on the background queue.
        succeed().upon() { res in
            self.dequeueQueuedTabs(receivedURLs: receivedURLs ?? [])
        }
    }

    fileprivate func dequeueQueuedTabs(receivedURLs: [URL]) {
        assert(!Thread.current.isMainThread, "This must be called in the background.")
        self.profile.queue.getQueuedTabs() >>== { cursor in

            // This assumes that the DB returns rows in some kind of sane order.
            // It does in practice, so WFM.
            if cursor.count > 0 {

                // Filter out any tabs received by a push notification to prevent dupes.
                let urls = cursor.compactMap { $0?.url.asURL }.filter { !receivedURLs.contains($0) }
                if !urls.isEmpty {
                    DispatchQueue.main.async {
                        self.tabManager.addTabsForURLs(urls, zombie: false)
                    }
                }

                // Clear *after* making an attempt to open. We're making a bet that
                // it's better to run the risk of perhaps opening twice on a crash,
                // rather than losing data.
                self.profile.queue.clearQueuedTabs()
            }

            // Then, open any received URLs from push notifications.
            if !receivedURLs.isEmpty {
                DispatchQueue.main.async {
                    self.tabManager.addTabsForURLs(receivedURLs, zombie: false)
                }
            }
        }
    }

    // Because crashedLastLaunch is sticky, it does not get reset, we need to remember its
    // value so that we do not keep asking the user to restore their tabs.
    var displayedRestoreTabsAlert = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // On iPhone, if we are about to show the On-Boarding, blank out the tab so that it does
        // not flash before we present. This change of alpha also participates in the animation when
        // the intro view is dismissed.
        if UIDevice.current.userInterfaceIdiom == .phone {
            self.view.alpha = Defaults[.introSeen] ? 1.0 : 0.0
        }

        // config log environment variable
        ClientLogger.shared.env = EnvironmentHelper.shared.env

        if !displayedRestoreTabsAlert && !cleanlyBackgrounded() && crashedLastLaunch() {
            displayedRestoreTabsAlert = true
            showRestoreTabsAlert()
        } else {
            tabManager.restoreTabs()
        }

        clipboardBarDisplayHandler?.checkIfShouldDisplayBar()
    }

    fileprivate func crashedLastLaunch() -> Bool {
        return Sentry.crashedLastLaunch
    }

    fileprivate func cleanlyBackgrounded() -> Bool {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return false
        }
        return appDelegate.applicationCleanlyBackgrounded
    }

    fileprivate func showRestoreTabsAlert() {
        guard tabManager.hasTabsToRestoreAtStartup() else {
            tabManager.selectTab(tabManager.addTab())
            return
        }
        let alert = UIAlertController.restoreTabsAlert(
            okayCallback: { _ in
                self.isCrashAlertShowing = false
                self.tabManager.restoreTabs(true)
            },
            noCallback: { _ in
                self.isCrashAlertShowing = false
                self.tabManager.selectTab(self.tabManager.addTab())
                self.openUrlAfterRestore()
            }
        )
        self.present(alert, animated: true, completion: nil)
        isCrashAlertShowing = true
    }

    override func viewDidAppear(_ animated: Bool) {
        presentIntroViewController()
        presentDBOnboardingViewController()
        presentUpdateViewController()
        screenshotHelper.viewIsVisible = true
        screenshotHelper.takePendingScreenshots(tabManager.tabs)

        super.viewDidAppear(animated)

        if let toast = self.pendingToast {
            self.pendingToast = nil
            show(toast: toast, afterWaiting: ButtonToastUX.ToastDelay)
        }
        showQueuedAlertIfAvailable()
    }

    // The logic for shouldShowWhatsNewTab is as follows: If we do not have the latestAppVersion key in
    // Defaults, that means that this is a fresh install and we do not show the What's New. If we do have
    // that value, we compare it to the major version of the running app. If it is different then this is an
    // upgrade, downgrades are not possible, so we can show the What's New page.

    func shouldShowWhatsNew() -> Bool {
        
        guard let latestMajorAppVersion = Defaults[.latestAppVersion]?.components(separatedBy: ".").first else {
            return false // Clean install, never show What's New
        }

        return latestMajorAppVersion != AppInfo.majorAppVersion && DeviceInfo.hasConnectivity()
    }

    fileprivate func showQueuedAlertIfAvailable() {
        if let queuedAlertInfo = tabManager.selectedTab?.dequeueJavascriptAlertPrompt() {
            let alertController = queuedAlertInfo.alertController()
            alertController.delegate = self
            present(alertController, animated: true, completion: nil)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        screenshotHelper.viewIsVisible = false
        super.viewWillDisappear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    func resetBrowserChrome() {
        // animate and reset transform for tab chrome
        legacyURLBar.updateAlphaForSubviews(1)
        footer.alpha = 1

        [header, footer, readerModeBar].forEach { view in
                view?.transform = .identity
        }
        statusBarOverlay.isHidden = false
    }

    override func updateViewConstraints() {
        super.updateViewConstraints()

        topTouchArea.snp.remakeConstraints { make in
            make.top.left.right.equalTo(self.view)
            make.height.equalTo(BrowserViewControllerUX.ShowHeaderTapAreaHeight)
        }

        readerModeBar?.snp.remakeConstraints { make in
            make.top.equalTo(self.header.snp.bottom)
            make.height.equalTo(UIConstants.ToolbarHeight)
            make.leading.trailing.equalTo(self.view)
        }

        webViewContainer.snp.remakeConstraints { make in
            make.left.right.equalTo(self.view)

            if let readerModeBarBottom = readerModeBar?.snp.bottom {
                make.top.equalTo(readerModeBarBottom)
            } else {
                make.top.equalTo(self.header.snp.bottom)
            }

            let findInPageHeight = (findInPageBar == nil) ? 0 : UIConstants.ToolbarHeight
            if let toolbar = self.toolbar {
                make.bottom.equalTo(toolbar.snp.top).offset(-findInPageHeight)
            } else {
                make.bottom.equalTo(self.view).offset(-findInPageHeight)
            }
        }

        // Setup the bottom toolbar
        toolbar?.snp.remakeConstraints { make in
            make.edges.equalTo(self.footer)
            make.height.equalTo(UIConstants.BottomToolbarHeight(in: view.window))
        }

        footer.snp.remakeConstraints { make in
            scrollController.footerBottomConstraint = make.bottom.equalTo(self.view.snp.bottom).constraint
            make.leading.trailing.equalTo(self.view)
        }

        legacyURLBar.setNeedsUpdateConstraints()

        // Remake constraints even if we're already showing the home controller.
        // The home controller may change sizes if we tap the URL bar while on about:home.
        neevaHomeViewController?.view.snp.remakeConstraints { make in
            make.top.equalTo(self.legacyURLBar.snp.bottom)
            make.left.right.equalTo(self.view)
            if self.homePanelIsInline {
                make.bottom.equalTo(self.toolbar?.snp.top ?? self.view.snp.bottom)
            } else {
                make.bottom.equalTo(self.view.snp.bottom)
            }
        }


        alertStackView.snp.remakeConstraints { make in
            make.centerX.equalTo(self.view)
            make.width.equalTo(self.view.safeArea.width)
            if let keyboardHeight = keyboardState?.intersectionHeightForView(self.view), keyboardHeight > 0 {
                make.bottom.equalTo(self.view).offset(-keyboardHeight)
            } else if let toolbar = self.toolbar {
                make.bottom.lessThanOrEqualTo(toolbar.snp.top)
                make.bottom.lessThanOrEqualTo(self.view.safeArea.bottom)
            } else {
                make.bottom.equalTo(self.view.safeArea.bottom)
            }
        }
    }

    fileprivate func showNeevaHome(inline: Bool) {
        homePanelIsInline = inline
        if self.neevaHomeViewController == nil {
            let neevaHomeViewController = NeevaHomeViewController(profile: profile)
            neevaHomeViewController.homePanelDelegate = self
            self.neevaHomeViewController = neevaHomeViewController
            addChild(neevaHomeViewController)
            view.addSubview(neevaHomeViewController.view)
            neevaHomeViewController.didMove(toParent: self)
        }

        // We have to run this animation, even if the view is already showing
        // because there may be a hide animation running and we want to be sure
        // to override its results.
        UIView.animate(withDuration: 0.2, animations: { () -> Void in
            self.neevaHomeViewController?.view.alpha = 1
        }, completion: { finished in
            if finished {
                self.webViewContainer.accessibilityElementsHidden = true
                UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged, argument: nil)
            }
        })
        view.setNeedsUpdateConstraints()
        legacyURLBar.legacyLocationView.reloadButton.reloadButtonState = .disabled
    }

    fileprivate func hideNeevaHome() {
        guard let neevaHomeViewController = self.neevaHomeViewController else {
            return
        }

        self.neevaHomeViewController = nil
        UIView.animate(withDuration: 0.2, delay: 0, options: .beginFromCurrentState, animations: { () -> Void in
            neevaHomeViewController.view.alpha = 0
        }, completion: { _ in
            neevaHomeViewController.willMove(toParent: nil)
            neevaHomeViewController.view.removeFromSuperview()
            neevaHomeViewController.removeFromParent()
            self.webViewContainer.accessibilityElementsHidden = false
            UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged, argument: nil)

            // Refresh the reading view toolbar since the article record may have changed
            if let readerMode = self.tabManager.selectedTab?.getContentScript(name: ReaderMode.name()) as? ReaderMode, readerMode.state == .active {
                self.showReaderModeBar(animated: false)
            }
        })
        legacyURLBar.legacyLocationView.reloadButton.reloadButtonState = .reload
    }

    fileprivate func updateInContentHomePanel(_ url: URL?) {
        let isAboutHomeURL = url.flatMap { InternalURL($0)?.isAboutHomeURL } ?? false
        if !legacyURLBar.inOverlayMode {
            guard let url = url else {
                hideNeevaHome()
                return
            }
            if isAboutHomeURL {
                showNeevaHome(inline: true)
            } else if !url.absoluteString.hasPrefix("\(InternalURL.baseUrl)/\(SessionRestoreHandler.path)") {
                hideNeevaHome()
            }
        } else if isAboutHomeURL {
            showNeevaHome(inline: false)
        }
    }

    func showLibrary(panel: LibraryPanelType? = nil) {
        if let presentedViewController = self.presentedViewController {
            presentedViewController.dismiss(animated: true, completion: nil)
        }

        let libraryViewController = self.libraryViewController ?? LibraryViewController(profile: profile)
        libraryViewController.delegate = self
        self.libraryViewController = libraryViewController

        if panel != nil {
            libraryViewController.selectedPanel = panel
        }

        let libraryDrawerViewController = self.libraryDrawerViewController ?? DrawerViewController(childViewController: libraryViewController)
        self.libraryDrawerViewController = libraryDrawerViewController

        addChild(libraryDrawerViewController)
        view.addSubview(libraryDrawerViewController.view)
        libraryDrawerViewController.view.snp.remakeConstraints(constraintsForLibraryDrawerView)
    }

    func showOverlaySheetViewController(_ overlaySheetViewController: UIViewController) {
        hideOverlaySheetViewController()

        addChild(overlaySheetViewController)
        view.addSubview(overlaySheetViewController.view)
        overlaySheetViewController.view.snp.makeConstraints { make in
            make.edges.equalTo(self.view)
        }
        overlaySheetViewController.didMove(toParent: self)

        self.overlaySheetViewController = overlaySheetViewController
        
        UIAccessibility.post(notification: .screenChanged, argument: overlaySheetViewController.view)
    }

    func hideOverlaySheetViewController() {
        if let overlaySheetViewController = self.overlaySheetViewController {
            overlaySheetViewController.willMove(toParent: nil)
            overlaySheetViewController.view.removeFromSuperview()
            overlaySheetViewController.removeFromParent()
            self.overlaySheetViewController = nil
        }
    }

    fileprivate func createSearchControllerIfNeeded() {
        guard self.searchController == nil else {
            return
        }

        let isPrivate = tabManager.selectedTab?.isPrivate ?? false
        let searchController = SearchViewController(profile: profile, isPrivate: isPrivate)
        searchController.searchDelegate = self

        let searchLoader = SearchLoader(profile: profile, urlBar: legacyURLBar)
        searchLoader.addListener(searchController)

        self.searchController = searchController
        self.searchLoader = searchLoader
    }

    fileprivate func showSearchController() {
        createSearchControllerIfNeeded()

        guard let searchController = self.searchController else {
            return
        }

        addChild(searchController)
        view.addSubview(searchController.view)
        searchController.view.snp.makeConstraints { make in
            make.top.equalTo(self.legacyURLBar.snp.bottom)
            make.left.right.bottom.equalTo(self.view)
        }

        neevaHomeViewController?.view?.isHidden = true

        searchController.didMove(toParent: self)
    }

    fileprivate func hideSearchController() {
        if let searchController = self.searchController {
            searchController.willMove(toParent: nil)
            searchController.view.removeFromSuperview()
            searchController.removeFromParent()
            neevaHomeViewController?.view?.isHidden = false
        }
    }

    fileprivate func destroySearchController() {
        hideSearchController()

        searchController = nil
        searchLoader = nil
    }
    
    func finishEditingAndSubmit(_ url: URL, visitType: VisitType, forTab tab: Tab) {
        legacyURLBar.currentURL = url
        legacyURLBar.leaveOverlayMode()

        if let nav = tab.loadRequest(URLRequest(url: url)) {
            self.recordNavigationInTab(tab, navigation: nav, visitType: visitType)
        }
    }
    
    override func accessibilityPerformEscape() -> Bool {
        if legacyURLBar.inOverlayMode {
            legacyURLBar.didClickCancel()
            return true
        } else if let selectedTab = tabManager.selectedTab, selectedTab.canGoBack {
            selectedTab.goBack()
            return true
        }
        return false
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let webView = object as? WKWebView, let tab = tabManager[webView] else {
            assert(false)
            return
        }
        guard let kp = keyPath, let path = KVOConstants(rawValue: kp) else {
            assertionFailure("Unhandled KVO key: \(keyPath ?? "nil")")
            return
        }

        if let helper = tab.getContentScript(name: ContextMenuHelper.name()) as? ContextMenuHelper {
            // This is zero-cost if already installed. It needs to be checked frequently (hence every event here triggers this function), as when a new tab is created it requires multiple attempts to setup the handler correctly.
             helper.replaceGestureHandlerIfNeeded()
        }

        switch path {
        case .estimatedProgress:
            guard tab === tabManager.selectedTab else { break }
            if let url = webView.url, !InternalURL.isValid(url: url) {
                legacyURLBar.updateProgressBar(Float(webView.estimatedProgress))
            } else {
                legacyURLBar.hideProgressBar()
            }
        case .loading:
            break
        case .URL:
            // Special case for "about:blank" popups, if the webView.url is nil, keep the tab url as "about:blank"
            if tab.url?.absoluteString == "about:blank" && webView.url == nil {
                break
            }

            // To prevent spoofing, only change the URL immediately if the new URL is on
            // the same origin as the current URL. Otherwise, do nothing and wait for
            // didCommitNavigation to confirm the page load.
            if tab.url?.origin == webView.url?.origin {
                tab.url = webView.url

                if tab === tabManager.selectedTab && !tab.restoring {
                    updateUIForReaderHomeStateForTab(tab)
                }
                // Catch history pushState navigation, but ONLY for same origin navigation,
                // for reasons above about URL spoofing risk.
                navigateInTab(tab: tab, webViewStatus: .url)
            }
        case .title:
            // Ensure that the tab title *actually* changed to prevent repeated calls
            // to navigateInTab(tab:).
            guard let title = tab.title else { break }
            if !title.isEmpty && title != tab.lastTitle {
                tab.lastTitle = title
                navigateInTab(tab: tab, webViewStatus: .title)
            }
        case .canGoBack:
            guard tab === tabManager.selectedTab, let canGoBack = change?[.newKey] as? Bool else {
                break
            }
            navigationToolbar.updateBackStatus(canGoBack)
        case .canGoForward:
            guard tab === tabManager.selectedTab, let canGoForward = change?[.newKey] as? Bool else {
                break
            }
            navigationToolbar.updateForwardStatus(canGoForward)
        default:
            assertionFailure("Unhandled KVO key: \(keyPath ?? "nil")")
        }
    }

    func updateUIForReaderHomeStateForTab(_ tab: Tab) {
        updateURLBarDisplayURL(tab)
        scrollController.showToolbars(animated: false)

        if let url = tab.url {
            if url.isReaderModeURL {
                showReaderModeBar(animated: false)
                NotificationCenter.default.addObserver(self, selector: #selector(dynamicFontChanged), name: .DynamicFontChanged, object: nil)
            } else {
                hideReaderModeBar(animated: false)
                NotificationCenter.default.removeObserver(self, name: .DynamicFontChanged, object: nil)
            }

            updateInContentHomePanel(url as URL)
        }
    }

    /// Updates the URL bar text and button states.
    /// Call this whenever the page URL changes.
    fileprivate func updateURLBarDisplayURL(_ tab: Tab) {
        legacyURLBar.currentURL = tab.url?.displayURL
        legacyURLBar.legacyLocationView.showLockIcon(forSecureContent: tab.webView?.hasOnlySecureContent ?? false)

        let isPage = tab.url?.displayURL?.isWebPage() ?? false
        legacyURLBar.legacyLocationView.updateShareButton(isPage)
        navigationToolbar.updatePageStatus(isPage)
    }

    // MARK: Opening New Tabs
    func switchToPrivacyMode(isPrivate: Bool) {
        if let tabTrayController = self.tabTrayController, tabTrayController.tabDisplayManager.isPrivate != isPrivate {
            tabTrayController.changePrivacyMode(isPrivate)
        }
        topTabsViewController?.applyUIMode(isPrivate: isPrivate)
    }

    func switchToTabForURLOrOpen(_ url: URL, isPrivate: Bool = false) {
        guard !isCrashAlertShowing else {
            urlFromAnotherApp = UrlToOpenModel(url: url, isPrivate: isPrivate)
            return
        }
        popToBVC()
        if let tab = tabManager.getTabForURL(url) {
            tabManager.selectTab(tab)
        } else {
            openURLInNewTab(url, isPrivate: isPrivate)
        }
    }
    
    func switchToTabForWidgetURLOrOpen(_ url: URL, uuid: String,  isPrivate: Bool = false) {
        guard !isCrashAlertShowing else {
            urlFromAnotherApp = UrlToOpenModel(url: url, isPrivate: isPrivate)
            return
        }
        popToBVC()
        if let tab = tabManager.getTabForUUID(uuid: uuid) {
            tabManager.selectTab(tab)
        } else {
            openURLInNewTab(url, isPrivate: isPrivate)
        }
    }

    func openURLInNewTab(_ url: URL?, isPrivate: Bool = false) {
        if let selectedTab = tabManager.selectedTab {
            screenshotHelper.takeScreenshot(selectedTab)
        }
        let request: URLRequest?
        if let url = url {
            request = URLRequest(url: url)
        } else {
            request = nil
        }

        switchToPrivacyMode(isPrivate: isPrivate)
        tabManager.selectTab(tabManager.addTab(request, isPrivate: isPrivate))
    }

    func focusLocationTextField(forTab tab: Tab?, setSearchText searchText: String? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
            // Without a delay, the text field fails to become first responder
            // Check that the newly created tab is still selected.
            // This let's the user spam the Cmd+T button without lots of responder changes.
            guard tab == self.tabManager.selectedTab else { return }
            self.legacyURLBar.tabLocationViewDidTapLocation(self.legacyURLBar.legacyLocationView)
            if let text = searchText {
                self.legacyURLBar.setLocation(text, search: true)
            }
        }
    }

    func openBlankNewTab(focusLocationField: Bool, isPrivate: Bool = false, searchFor searchText: String? = nil) {
        popToBVC()
        openURLInNewTab(nil, isPrivate: isPrivate)
        let freshTab = tabManager.selectedTab
        if focusLocationField {
            focusLocationTextField(forTab: freshTab, setSearchText: searchText)
        }
    }

    func openSearchNewTab(isPrivate: Bool = false, _ text: String) {
        popToBVC()
        if let searchURL = neevaSearchEngine.searchURLForQuery(text) {
            openURLInNewTab(searchURL, isPrivate: isPrivate)
        } else {
            // We still don't have a valid URL, so something is broken. Give up.
            print("Error handling URL entry: \"\(text)\".")
            assertionFailure("Couldn't generate search URL: \(text)")
        }
    }

    fileprivate func popToBVC() {
        guard let currentViewController = navigationController?.topViewController else {
            return
        }
        currentViewController.dismiss(animated: true, completion: nil)
        if currentViewController != self {
            _ = self.navigationController?.popViewController(animated: true)
        } else if legacyURLBar.inOverlayMode {
            legacyURLBar.didClickCancel()
        }
    }

    func presentActivityViewController(_ url: URL, tab: Tab? = nil, sourceView: UIView?, sourceRect: CGRect, arrowDirection: UIPopoverArrowDirection) {
        let helper = ShareExtensionHelper(url: url, tab: tab)

        var appActivities = [UIActivity]()

        let findInPageActivity = FindOnPageActivity() { [unowned self] in
            self.updateFindInPageVisibility(visible: true)
        }
        appActivities.append(findInPageActivity)

        let deferredSites = self.profile.history.isPinnedTopSite(tab?.url?.absoluteString ?? "")

        let isPinned = deferredSites.value.successValue ?? false

        if FeatureFlag[.pinToTopSites] {
            var topSitesActivity: PinToTopSitesActivity
            if isPinned == false {
                topSitesActivity = PinToTopSitesActivity(isPinned: isPinned) { [weak tab] in
                    guard let url = tab?.url?.displayURL, let sql = self.profile.history as? SQLiteHistory else { return }

                    sql.getSites(forURLs: [url.absoluteString]).bind { val -> Success in
                        guard let site = val.successValue?.asArray().first?.flatMap({ $0 }) else {
                            return succeed()
                        }
                        return self.profile.history.addPinnedTopSite(site)
                    }.uponQueue(.main) { result in
                        if result.isSuccess {
                            SimpleToast().showAlertWithText(Strings.AppMenuAddPinToTopSitesConfirmMessage, bottomContainer: self.webViewContainer)
                        }
                    }
                }
            } else {
                topSitesActivity = PinToTopSitesActivity(isPinned: isPinned) { [weak tab] in
                    guard let url = tab?.url?.displayURL, let sql = self.profile.history as? SQLiteHistory else { return }

                    sql.getSites(forURLs: [url.absoluteString]).bind { val -> Success in
                        guard let site = val.successValue?.asArray().first?.flatMap({ $0 }) else {
                            return succeed()
                        }

                        return self.profile.history.removeFromPinnedTopSites(site)
                    }.uponQueue(.main) { result in
                        if result.isSuccess {
                            SimpleToast().showAlertWithText(Strings.AppMenuRemovePinFromTopSitesConfirmMessage, bottomContainer: self.webViewContainer)
                        }
                    }
                }
            }
            appActivities.append(topSitesActivity)
        }

        if let tab = tabManager.selectedTab,
           let readerMode = tab.getContentScript(name: "ReaderMode") as? ReaderMode,
           readerMode.state != .unavailable,
           FeatureFlag[.readingMode] {
            let readingModeActivity = ReadingModeActivity(readerModeState: readerMode.state) { [unowned self] in
                switch readerMode.state {
                case .available:
                    enableReaderMode()
                case .active:
                    disableReaderMode()
                case .unavailable:
                    break
                }
            }
            appActivities.append(readingModeActivity)
        }


        let requestDesktopSiteActivity = RequestDesktopSiteActivity(tab: tab) { [weak tab] in
            tab?.toggleChangeUserAgent()
            Tab.ChangeUserAgent.updateDomainList(forUrl: url, isChangedUA: tab?.changedUserAgent ?? false, isPrivate: tab?.isPrivate ?? false)
        }
        appActivities.append(requestDesktopSiteActivity)

        

        let controller = helper.createActivityViewController(appActivities: appActivities) { [unowned self] completed, _ in
            // After dismissing, check to see if there were any prompts we queued up
            self.showQueuedAlertIfAvailable()

            // Usually the popover delegate would handle nil'ing out the references we have to it
            // on the BVC when displaying as a popover but the delegate method doesn't seem to be
            // invoked on iOS 10. See Bug 1297768 for additional details.
            self.displayedPopoverController = nil
            self.updateDisplayedPopoverProperties = nil
        }

        if let popoverPresentationController = controller.popoverPresentationController {
            popoverPresentationController.sourceView = sourceView
            popoverPresentationController.sourceRect = sourceRect
            popoverPresentationController.permittedArrowDirections = arrowDirection
            popoverPresentationController.delegate = self
        }

        present(controller, animated: true, completion: nil)
    }

    @objc fileprivate func openSettings() {
        assert(Thread.isMainThread, "Opening settings requires being invoked on the main thread")

        let controller = SettingsViewController(bvc: self)
        self.present(controller, animated: true, completion: nil)
    }

    fileprivate func postLocationChangeNotificationForTab(_ tab: Tab, navigation: WKNavigation?) {
        let notificationCenter = NotificationCenter.default
        var info = [AnyHashable: Any]()
        info["url"] = tab.url?.displayURL
        info["title"] = tab.title
        if let visitType = self.getVisitTypeForTab(tab, navigation: navigation)?.rawValue {
            info["visitType"] = visitType
        }
        info["isPrivate"] = tab.isPrivate
        notificationCenter.post(name: .OnLocationChange, object: self, userInfo: info)
    }

    /// Enum to represent the WebView observation or delegate that triggered calling `navigateInTab`
    enum WebViewUpdateStatus {
        case title
        case url
        case finishedNavigation
    }
    
    func navigateInTab(tab: Tab, to navigation: WKNavigation? = nil, webViewStatus: WebViewUpdateStatus) {
        tabManager.expireSnackbars()

        guard let webView = tab.webView else {
            print("Cannot navigate in tab without a webView")
            return
        }

        if let url = webView.url {
            if tab === tabManager.selectedTab {
                legacyURLBar.legacyLocationView.showLockIcon(forSecureContent: webView.hasOnlySecureContent)
                let isPage = tab.url?.displayURL?.isWebPage() ?? false
                legacyURLBar.legacyLocationView.updateShareButton(isPage)
            }

            if (!InternalURL.isValid(url: url) || url.isReaderModeURL), !url.isFileURL {
                postLocationChangeNotificationForTab(tab, navigation: navigation)

                webView.evaluateJavascriptInDefaultContentWorld("\(ReaderModeNamespace).checkReadability()")
            }

            TabEvent.post(.didChangeURL(url), for: tab)
        }
        
        // Represents WebView observation or delegate update that called this function
        switch webViewStatus {
        case .title, .url, .finishedNavigation:
            if tab !== tabManager.selectedTab, let webView = tab.webView {
                // To Screenshot a tab that is hidden we must add the webView,
                // then wait enough time for the webview to render.
                view.insertSubview(webView, at: 0)
                // This is kind of a hacky fix for Bug 1476637 to prevent webpages from focusing the
                // touch-screen keyboard from the background even though they shouldn't be able to.
                webView.resignFirstResponder()
                
                // We need a better way of identifying when webviews are finished rendering
                // There are cases in which the page will still show a loading animation or nothing when the screenshot is being taken,
                // depending on internet connection
                // Issue created: https://github.com/mozilla-mobile/firefox-ios/issues/7003
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1000)) {
                    self.screenshotHelper.takeScreenshot(tab)
                    if webView.superview == self.view {
                        webView.removeFromSuperview()
                    }
                }
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection), ThemeManager.instance.systemThemeIsOn {
                let userInterfaceStyle = traitCollection.userInterfaceStyle
                ThemeManager.instance.current = userInterfaceStyle == .dark ? DarkTheme() : NormalTheme()
            }
        }
    }
}

extension BrowserViewController: ClipboardBarDisplayHandlerDelegate {
    func shouldDisplay(clipboardBar bar: ButtonToast) {
        show(toast: bar, duration: ClipboardBarToastUX.ToastDelay)
    }
}

extension BrowserViewController: SettingsDelegate {
    func settingsOpenURLInNewTab(_ url: URL) {
        let isPrivate = tabManager.selectedTab?.isPrivate ?? false
        self.openURLInNewTab(url, isPrivate: isPrivate)
    }
    func settingsOpenURLInNewNonPrivateTab(_ url: URL) {
        self.openURLInNewTab(url, isPrivate: false)
    }
}

extension BrowserViewController: PresentingModalViewControllerDelegate {
    func dismissPresentedModalViewController(_ modalViewController: UIViewController, animated: Bool) {
        self.dismiss(animated: animated, completion: nil)
    }
}

/**
 * History visit management.
 * TODO: this should be expanded to track various visit types; see Bug 1166084.
 */
extension BrowserViewController {
    func ignoreNavigationInTab(_ tab: Tab, navigation: WKNavigation) {
        self.ignoredNavigation.insert(navigation)
    }

    func recordNavigationInTab(_ tab: Tab, navigation: WKNavigation, visitType: VisitType) {
        self.typedNavigation[navigation] = visitType
    }

    /**
     * Untrack and do the right thing.
     */
    func getVisitTypeForTab(_ tab: Tab, navigation: WKNavigation?) -> VisitType? {
        guard let navigation = navigation else {
            // See https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/Cocoa/NavigationState.mm#L390
            return VisitType.link
        }

        if let _ = self.ignoredNavigation.remove(navigation) {
            return nil
        }

        return self.typedNavigation.removeValue(forKey: navigation) ?? VisitType.link
    }
}

extension BrowserViewController: LegacyURLBarDelegate {
    func showTabTray() {
        // log show tap tray
        ClientLogger.shared.logCounter(.ShowTabTray, attributes: EnvironmentHelper.shared.getAttributes())

        Sentry.shared.clearBreadcrumbs()

        updateFindInPageVisibility(visible: false)
        
        let tabTrayController = TabTrayControllerV1(tabManager: tabManager, profile: profile, tabTrayDelegate: self)
        navigationController?.pushViewController(tabTrayController, animated: true)
        self.tabTrayController = tabTrayController

        if let tab = tabManager.selectedTab {
            screenshotHelper.takeScreenshot(tab)
        }

        TelemetryWrapper.recordEvent(category: .action, method: .open, object: .tabTray)
    }

    func urlBarDidPressReload(_ urlBar: LegacyURLBarView) {
        // log tap reload
        ClientLogger.shared.logCounter(.TapReload, attributes: EnvironmentHelper.shared.getAttributes())

        tabManager.selectedTab?.reload()
    }

    func urlBarNeevaMenu(_ urlBar: LegacyURLBarView, from button: UIButton){
        let isPrivate = tabManager.selectedTab?.isPrivate ?? false
        let host = PopOverNeevaMenuViewController(
            delegate: self,
            source: button, isPrivate: isPrivate,
            feedbackImage: screenshot())
        self.popOverNeevaMenuViewController = host
        // log tap neeva menu
        ClientLogger.shared.logCounter(.OpenNeevaMenu, attributes: EnvironmentHelper.shared.getAttributes())

        //Fix autolayout sizing
        host.view.backgroundColor = UIColor.PopupMenu.background
        host.preferredContentSize = host.sizeThatFits(in: CGSize(width: 340, height: 315))
        present(
            host,
            animated: true,
            completion: nil)
    }
    
    func neevaMenuDidRequestToOpenPage(page: NeevaMenuButtonActions) {
        switch(page){
        case .home:
            switchToTabForURLOrOpen(NeevaConstants.appHomeURL)
            break
        case .spaces:
            switchToTabForURLOrOpen(NeevaConstants.appSpacesURL)
            break
        default:
            break
        }
    }
    
    func urlBarDidTapShield(_ urlBar: LegacyURLBarView, from button: UIButton) {
        let host = PopOverTrackingMenuViewController(
            delegate: self,
            source: button)

        // log tap shield
        ClientLogger.shared.logCounter(.OpenShield, attributes: EnvironmentHelper.shared.getAttributes())

        //Fix autolayout sizing
        host.view.backgroundColor = UIColor.PopupMenu.background
        host.preferredContentSize = host.sizeThatFits(in: CGSize(width: 340, height: 120))
        present(
            host,
            animated: true,
            completion: nil)
    }

    func urlBarDidPressStop(_ urlBar: LegacyURLBarView) {
        tabManager.selectedTab?.stop()
    }

    func urlBarDidPressTabs(_ urlBar: LegacyURLBarView) {
        showTabTray()
    }

    func urlBarDidPressReaderMode(_ urlBar: LegacyURLBarView) {
        libraryDrawerViewController?.close()

        guard let tab = tabManager.selectedTab, let readerMode = tab.getContentScript(name: "ReaderMode") as? ReaderMode else {
            return
        }
        switch readerMode.state {
        case .available:
            enableReaderMode()
            TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .readerModeOpenButton)
        case .active:
            disableReaderMode()
            TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .readerModeCloseButton)
        case .unavailable:
            break
        }
    }

    func urlBarDidLongPressReaderMode(_ urlBar: LegacyURLBarView) -> Bool {
        guard let tab = tabManager.selectedTab,
               let url = tab.url?.displayURL
            else {
            UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: String.ReaderModeAddPageGeneralErrorAccessibilityLabel)
                return false
        }

        let result = profile.readingList.createRecordWithURL(url.absoluteString, title: tab.title ?? "", addedBy: UIDevice.current.name)

        switch result.value {
        case .success:
            UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: String.ReaderModeAddPageSuccessAcessibilityLabel)
            SimpleToast().showAlertWithText(Strings.ShareAddToReadingListDone, bottomContainer: self.webViewContainer)
        case .failure(let error):
            UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: String.ReaderModeAddPageMaybeExistsErrorAccessibilityLabel)
            print("readingList.createRecordWithURL(url: \"\(url.absoluteString)\", ...) failed with error: \(error)")
        }
        return true
    }

    func urlBarReloadMenu(_ urlBar: LegacyURLBarView, from button: UIButton) -> UIMenu? {
        guard let tab = tabManager.selectedTab else {
            return nil
        }
        return self.getRefreshLongPressMenu(for: tab)
    }

    func locationActionsForURLBar(_ urlBar: LegacyURLBarView) -> [AccessibleAction] {
        if UIPasteboard.general.string != nil {
            return [pasteGoAction, pasteAction, copyAddressAction]
        } else {
            return [copyAddressAction]
        }
    }

    func urlBarDidLongPressLocation(_ urlBar: LegacyURLBarView) {
        let urlActions = self.getLongPressLocationBarActions(with: urlBar, webViewContainer: self.webViewContainer)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        self.presentSheetWith(actions: [urlActions], on: self, from: urlBar)
    }

    func urlBarDidPressScrollToTop(_ urlBar: LegacyURLBarView) {
        if let selectedTab = tabManager.selectedTab, neevaHomeViewController == nil {
            // Only scroll to top if we are not showing the home view controller
            selectedTab.webView?.scrollView.setContentOffset(CGPoint.zero, animated: true)
        }
    }

    func urlBarLocationAccessibilityActions(_ urlBar: LegacyURLBarView) -> [UIAccessibilityCustomAction]? {
        return locationActionsForURLBar(urlBar).map { $0.accessibilityCustomAction }
    }

    func urlBar(_ urlBar: LegacyURLBarView, didRestoreText text: String) {
        if text.isEmpty {
            hideSearchController()
        } else {
            showSearchController()
        }

        searchController?.searchQuery = text
        searchLoader?.setQueryWithoutAutocomplete(text)
    }

    func urlBar(_ urlBar: LegacyURLBarView, didEnterText text: String) {
        if text.isEmpty {
            hideSearchController()
        } else {
            showSearchController()
        }

        searchController?.searchQuery = text
        searchLoader?.query = text
    }

    func urlBar(_ urlBar: LegacyURLBarView, didSubmitText text: String) {
        guard let currentTab = tabManager.selectedTab else { return }

        if let fixupURL = URIFixup.getURL(text) {
            // The user entered a URL, so use it.
            finishEditingAndSubmit(fixupURL, visitType: VisitType.typed, forTab: currentTab)
            return
        }

        // We couldn't build a URL, so check for a matching search keyword.
        let trimmedText = text.trimmingCharacters(in: .whitespaces)
        guard trimmedText.firstIndex(of: " ") != nil else {
            submitSearchText(text, forTab: currentTab)
            return
        }

        self.submitSearchText(text, forTab: currentTab)
    }

    fileprivate func submitSearchText(_ text: String, forTab tab: Tab) {
        
        if let searchURL = neevaSearchEngine.searchURLForQuery(text) {
            // We couldn't find a matching search keyword, so do a search query.
            finishEditingAndSubmit(searchURL, visitType: VisitType.typed, forTab: tab)
        } else {
            // We still don't have a valid URL, so something is broken. Give up.
            print("Error handling URL entry: \"\(text)\".")
            assertionFailure("Couldn't generate search URL: \(text)")
        }
    }

    func urlBarDidEnterOverlayMode(_ urlBar: LegacyURLBarView) {
        libraryDrawerViewController?.close()

        if let toast = clipboardBarDisplayHandler?.clipboardToast {
            toast.removeFromSuperview()
        }

        showNeevaHome(inline: false)
    }

    func urlBarDidLeaveOverlayMode(_ urlBar: LegacyURLBarView) {
        destroySearchController()
        updateInContentHomePanel(tabManager.selectedTab?.url as URL?)
    }

    func urlBarDidBeginDragInteraction(_ urlBar: LegacyURLBarView) {
        dismissVisibleMenus()
    }
}

extension BrowserViewController: TabDelegate {

    func tab(_ tab: Tab, didCreateWebView webView: WKWebView) {
        webView.frame = webViewContainer.frame
        // Observers that live as long as the tab. Make sure these are all cleared in willDeleteWebView below!
        KVOs.forEach { webView.addObserver(self, forKeyPath: $0.rawValue, options: .new, context: nil) }
        webView.scrollView.addObserver(self.scrollController, forKeyPath: KVOConstants.contentSize.rawValue, options: .new, context: nil)
        webView.uiDelegate = self

        let formPostHelper = FormPostHelper(tab: tab)
        tab.addContentScript(formPostHelper, name: FormPostHelper.name())

        let readerMode = ReaderMode(tab: tab)
        readerMode.delegate = self
        tab.addContentScript(readerMode, name: ReaderMode.name())

        // only add the logins helper if the tab is not a private browsing tab
        if !tab.isPrivate {
            let logins = LoginsHelper(tab: tab, profile: profile)
            tab.addContentScript(logins, name: LoginsHelper.name())
        }

        let contextMenuHelper = ContextMenuHelper(tab: tab)
        contextMenuHelper.delegate = self
        tab.addContentScript(contextMenuHelper, name: ContextMenuHelper.name())

        let errorHelper = ErrorPageHelper(certStore: profile.certStore)
        tab.addContentScript(errorHelper, name: ErrorPageHelper.name())

        let sessionRestoreHelper = SessionRestoreHelper(tab: tab)
        sessionRestoreHelper.delegate = self
        tab.addContentScript(sessionRestoreHelper, name: SessionRestoreHelper.name())

        let findInPageHelper = FindInPageHelper(tab: tab)
        findInPageHelper.delegate = self
        tab.addContentScript(findInPageHelper, name: FindInPageHelper.name())

        let downloadContentScript = DownloadContentScript(tab: tab)
        tab.addContentScript(downloadContentScript, name: DownloadContentScript.name())

        let printHelper = PrintHelper(tab: tab)
        tab.addContentScript(printHelper, name: PrintHelper.name())

        let nightModeHelper = NightModeHelper(tab: tab)
        tab.addContentScript(nightModeHelper, name: NightModeHelper.name())

        // XXX: Bug 1390200 - Disable NSUserActivity/CoreSpotlight temporarily
        // let spotlightHelper = SpotlightHelper(tab: tab)
        // tab.addHelper(spotlightHelper, name: SpotlightHelper.name())

        tab.addContentScript(LocalRequestHelper(), name: LocalRequestHelper.name())

        let blocker = NeevaTabContentBlocker(tab: tab)
        tab.contentBlocker = blocker
        tab.addContentScript(blocker, name: NeevaTabContentBlocker.name())

        tab.addContentScript(FocusHelper(tab: tab), name: FocusHelper.name())
    }

    func tab(_ tab: Tab, willDeleteWebView webView: WKWebView) {
        tab.cancelQueuedAlerts()
        KVOs.forEach { webView.removeObserver(self, forKeyPath: $0.rawValue) }
        webView.scrollView.removeObserver(self.scrollController, forKeyPath: KVOConstants.contentSize.rawValue)
        webView.uiDelegate = nil
        webView.scrollView.delegate = nil
        webView.removeFromSuperview()
    }

    fileprivate func findSnackbar(_ barToFind: SnackBar) -> Int? {
        let bars = alertStackView.arrangedSubviews
        for (index, bar) in bars.enumerated() where bar === barToFind {
            return index
        }
        return nil
    }

    func showBar(_ bar: SnackBar, animated: Bool) {
        view.layoutIfNeeded()
        UIView.animate(withDuration: animated ? 0.25 : 0, animations: {
            self.alertStackView.insertArrangedSubview(bar, at: 0)
            self.view.layoutIfNeeded()
        })
    }

    func removeBar(_ bar: SnackBar, animated: Bool) {
        UIView.animate(withDuration: animated ? 0.25 : 0, animations: {
            bar.removeFromSuperview()
        })
    }

    func removeAllBars() {
        alertStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    func tab(_ tab: Tab, didAddSnackbar bar: SnackBar) {
        // If the Tab that had a SnackBar added to it is not currently
        // the selected Tab, do nothing right now. If/when the Tab gets
        // selected later, we will show the SnackBar at that time.
        guard tab == tabManager.selectedTab else {
            return
        }

        showBar(bar, animated: true)
    }

    func tab(_ tab: Tab, didRemoveSnackbar bar: SnackBar) {
        removeBar(bar, animated: true)
    }

    func tab(_ tab: Tab, didSelectFindInPageForSelection selection: String) {
        updateFindInPageVisibility(visible: true)
        findInPageBar?.text = selection
    }

    func tab(_ tab: Tab, didSelectSearchWithNeevaForSelection selection: String) {
        openSearchNewTab(isPrivate: tab.isPrivate, selection)
    }
}

extension BrowserViewController: LibraryPanelDelegate {

    func libraryPanel(didSelectURL url: URL, visitType: VisitType) {
        guard let tab = tabManager.selectedTab else { return }
        finishEditingAndSubmit(url, visitType: visitType, forTab: tab)
        libraryDrawerViewController?.close()
    }

    func libraryPanel(didSelectURLString url: String, visitType: VisitType) {
        guard let url = URIFixup.getURL(url) ?? neevaSearchEngine.searchURLForQuery(url) else {
            Logger.browserLogger.warning("Invalid URL, and couldn't generate a search URL for it.")
            return
        }
        return self.libraryPanel(didSelectURL: url, visitType: visitType)
    }

    func libraryPanelDidRequestToOpenInNewTab(_ url: URL, isPrivate: Bool) {
        let tab = self.tabManager.addTab(URLRequest(url: url), afterTab: self.tabManager.selectedTab, isPrivate: isPrivate)
        // If we are showing toptabs a user can just use the top tab bar
        // If in overlay mode switching doesnt correctly dismiss the homepanels
        guard !topTabsVisible, !self.legacyURLBar.inOverlayMode else {
            return
        }
        // We're not showing the top tabs; show a toast to quick switch to the fresh new tab.
        let toast = ButtonToast(labelText: Strings.ContextMenuButtonToastNewTabOpenedLabelText, buttonText: Strings.ContextMenuButtonToastNewTabOpenedButtonText, completion: { buttonPressed in
            if buttonPressed {
                self.tabManager.selectTab(tab)
            }
        })
        self.show(toast: toast)
    }
}

extension BrowserViewController: HomePanelDelegate {
    func homePanelDidRequestToOpenLibrary(panel: LibraryPanelType) {
        showLibrary(panel: panel)
        view.endEditing(true)
    }

    func homePanel(didSelectURL url: URL, visitType: VisitType) {
        guard let tab = tabManager.selectedTab else { return }
        finishEditingAndSubmit(url, visitType: visitType, forTab: tab)
    }

    func homePanelDidRequestToOpenInNewTab(_ url: URL, isPrivate: Bool) {
        let tab = self.tabManager.addTab(URLRequest(url: url), afterTab: self.tabManager.selectedTab, isPrivate: isPrivate)
        // If we are showing toptabs a user can just use the top tab bar
        // If in overlay mode switching doesnt correctly dismiss the homepanels
        guard !topTabsVisible, !self.legacyURLBar.inOverlayMode else {
            return
        }
        // We're not showing the top tabs; show a toast to quick switch to the fresh new tab.
        let toast = ButtonToast(labelText: Strings.ContextMenuButtonToastNewTabOpenedLabelText, buttonText: Strings.ContextMenuButtonToastNewTabOpenedButtonText, completion: { buttonPressed in
            if buttonPressed {
                self.tabManager.selectTab(tab)
            }
        })
        self.show(toast: toast)
    }
    var homePanelIsPrivate: Bool { tabManager.selectedTab?.isPrivate ?? false }

    func homePanel(didEnterQuery query: String) {
        self.legacyURLBar.enterOverlayMode(query, pasted: true, search: true)
    }
}

extension BrowserViewController: SearchViewControllerDelegate {
    func searchViewController(_ searchViewController: SearchViewController, didSelectURL url: URL) {
        guard let tab = tabManager.selectedTab else { return }
        shouldSetUrlTypeSearch = true
        finishEditingAndSubmit(url, visitType: VisitType.typed, forTab: tab)
    }

    func searchViewController(_ searchViewController: SearchViewController, didAcceptSuggestion suggestion: String) {
        self.legacyURLBar.setLocation(suggestion, search: true)
    }

    func searchViewController(_ searchViewController: SearchViewController, didHighlightText text: String, search: Bool) {
        self.legacyURLBar.setLocation(text, search: search)
    }

    func searchViewController(_ searchViewController: SearchViewController, didUpdateLensOrBang lensOrBang: ActiveLensBangInfo?) {
        self.legacyURLBar.lensOrBang = lensOrBang
        if lensOrBang != nil {
            self.legacyURLBar.createLeftViewFavicon()
        }
    }

}

extension BrowserViewController: TabManagerDelegate {
    func tabManager(_ tabManager: TabManager, didSelectedTabChange selected: Tab?, previous: Tab?, isRestoring: Bool) {
        libraryDrawerViewController?.close(immediately: true)

        // Remove the old accessibilityLabel. Since this webview shouldn't be visible, it doesn't need it
        // and having multiple views with the same label confuses tests.
        if let wv = previous?.webView {
            wv.endEditing(true)
            wv.accessibilityLabel = nil
            wv.accessibilityElementsHidden = true
            wv.accessibilityIdentifier = nil
            wv.removeFromSuperview()
        }

        if let tab = selected, let webView = tab.webView {
            updateURLBarDisplayURL(tab)

            if previous == nil || tab.isPrivate != previous?.isPrivate {
                applyTheme()

                let ui: [PrivateModeUI?] = [topTabsViewController, toolbar, legacyURLBar]
                ui.forEach { $0?.applyUIMode(isPrivate: tab.isPrivate) }
            }

            readerModeCache = tab.isPrivate ? MemoryReaderModeCache.sharedInstance : DiskReaderModeCache.sharedInstance
            if let privateModeButton = topTabsViewController?.privateModeButton, previous != nil && previous?.isPrivate != tab.isPrivate {
                privateModeButton.setSelected(tab.isPrivate, animated: true)
            }
            ReaderModeHandlers.readerModeCache = readerModeCache

            scrollController.tab = tab
            webViewContainer.addSubview(webView)
            webView.snp.makeConstraints { make in
                make.left.right.top.bottom.equalTo(self.webViewContainer)
            }

            // This is a terrible workaround for a bad iOS 12 bug where PDF
            // content disappears any time the view controller changes (i.e.
            // the user taps on the tabs tray). It seems the only way to get
            // the PDF to redraw is to either reload it or revisit it from
            // back/forward list. To try and avoid hitting the network again
            // for the same PDF, we revisit the current back/forward item and
            // restore the previous scrollview zoom scale and content offset
            // after a short 100ms delay. *facepalm*
            //
            // https://bugzilla.mozilla.org/show_bug.cgi?id=1516524
            if #available(iOS 12.0, *) {
                if tab.mimeType == MIMEType.PDF {
                    let previousZoomScale = webView.scrollView.zoomScale
                    let previousContentOffset = webView.scrollView.contentOffset

                    if let currentItem = webView.backForwardList.currentItem {
                        webView.go(to: currentItem)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                        webView.scrollView.setZoomScale(previousZoomScale, animated: false)
                        webView.scrollView.setContentOffset(previousContentOffset, animated: false)
                    }
                }
            }

            webView.accessibilityLabel = .WebViewAccessibilityLabel
            webView.accessibilityIdentifier = "contentView"
            webView.accessibilityElementsHidden = false

            if webView.url == nil {
                // The web view can go gray if it was zombified due to memory pressure.
                // When this happens, the URL is nil, so try restoring the page upon selection.
                tab.reload()
            }
        }

        removeAllBars()
        if let bars = selected?.bars {
            for bar in bars {
                showBar(bar, animated: true)
            }
        }

        updateFindInPageVisibility(visible: false, tab: previous)
        navigationToolbar.updateBackStatus(simulateBackViewController?.canGoBack() ?? false
                                            || selected?.canGoBack ?? false)
        navigationToolbar.updateForwardStatus(simulateForwardViewController?.canGoForward() ?? false
                                                || selected?.canGoForward ?? false)
        if let url = selected?.webView?.url, !InternalURL.isValid(url: url) {
            self.legacyURLBar.updateProgressBar(Float(selected?.estimatedProgress ?? 0))
        }

        if let readerMode = selected?.getContentScript(name: ReaderMode.name()) as? ReaderMode {
            legacyURLBar.updateReaderModeState(readerMode.state)
            if readerMode.state == .active {
                showReaderModeBar(animated: false)
            } else {
                hideReaderModeBar(animated: false)
            }
        } else {
            legacyURLBar.updateReaderModeState(ReaderModeState.unavailable)
        }

        if topTabsVisible {
            topTabsDidChangeTab()
        }

        updateInContentHomePanel(selected?.url as URL?)
    }

    func tabManager(_ tabManager: TabManager, didAddTab tab: Tab, isRestoring: Bool) {
        tab.tabDelegate = self
    }

    func tabManager(_ tabManager: TabManager, didRemoveTab tab: Tab, isRestoring: Bool) {
        if let url = tab.url, !(InternalURL(url)?.isAboutURL ?? false), !tab.isPrivate {
            profile.recentlyClosedTabs.addTab(url as URL, title: tab.title, faviconURL: tab.displayFavicon?.url)
        }
    }

    func tabManagerDidAddTabs(_ tabManager: TabManager) {

    }

    func tabManagerDidRestoreTabs(_ tabManager: TabManager) {
        openUrlAfterRestore()
    }
    
    func openUrlAfterRestore() {
        guard let url = urlFromAnotherApp?.url else { return }
        openURLInNewTab(url, isPrivate: urlFromAnotherApp?.isPrivate ?? false)
        urlFromAnotherApp = nil
    }

    func show(toast: Toast, afterWaiting delay: DispatchTimeInterval = SimpleToastUX.ToastDelayBefore, duration: DispatchTimeInterval? = SimpleToastUX.ToastDismissAfter) {
        if let downloadToast = toast as? DownloadToast {
            self.downloadToast = downloadToast
        }

        // If BVC isnt visible hold on to this toast until viewDidAppear
        if self.view.window == nil {
            self.pendingToast = toast
            return
        }

        toast.showToast(viewController: self, delay: delay, duration: duration, makeConstraints: { make in
            make.left.right.equalTo(self.view)
            make.bottom.equalTo(self.webViewContainer?.snp.bottom ?? 0)
        })
    }

    func tabManagerDidRemoveAllTabs(_ tabManager: TabManager, toast: ButtonToast?) {
        let tabTrayV1PrivateMode = tabTrayController?.tabDisplayManager.isPrivate
        guard let toast = toast, !(tabTrayV1PrivateMode ?? false) else {
            return
        }
        show(toast: toast, afterWaiting: ButtonToastUX.ToastDelay)
    }
}

// MARK: - UIPopoverPresentationControllerDelegate

extension BrowserViewController: UIPopoverPresentationControllerDelegate {
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        displayedPopoverController = nil
        updateDisplayedPopoverProperties = nil
    }
}

extension BrowserViewController: UIAdaptivePresentationControllerDelegate {
    // Returning None here makes sure that the Popover is actually presented as a Popover and
    // not as a full-screen modal, which is the default on compact device classes.
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}

extension BrowserViewController {
    func presentIntroViewController(_ alwaysShow: Bool = false) {
        if alwaysShow || !Defaults[.introSeen] {
            showProperIntroVC()
        }
    }
    
    // Default browser onboarding
    func presentDBOnboardingViewController(_ force: Bool = false) {
        let shouldShow = DefaultBrowserOnboardingViewModel.shouldShowDefaultBrowserOnboarding()
        guard force || shouldShow else {
            return
        }
        let dBOnboardingViewController = DefaultBrowserOnboardingViewController()
        if topTabsVisible {
            dBOnboardingViewController.preferredContentSize = CGSize(width: ViewControllerConsts.PreferredSize.DBOnboardingViewController.width, height: ViewControllerConsts.PreferredSize.DBOnboardingViewController.height)
            dBOnboardingViewController.modalPresentationStyle = .formSheet
        } else {
            dBOnboardingViewController.modalPresentationStyle = .popover
        }
        dBOnboardingViewController.viewModel.goToSettings = {
            self.neevaHomeViewController?.homeViewModel.updateState()
            dBOnboardingViewController.dismiss(animated: true) {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:])
            }
        }
        present(dBOnboardingViewController, animated: true, completion: nil)
    }
    
    @discardableResult func presentUpdateViewController(_ force: Bool = false, animated: Bool = true) -> Bool {
        let cleanInstall = UpdateViewModel.isCleanInstall()
        let coverSheetSupportedAppVersion = UpdateViewModel.coverSheetSupportedAppVersion
        if force || UpdateViewModel.shouldShowUpdateSheet(isCleanInstall: cleanInstall, supportedAppVersions: coverSheetSupportedAppVersion) {
            let updateViewController = UpdateViewController()
            
            updateViewController.viewModel.startBrowsing = {
                updateViewController.dismiss(animated: true) {
                if self.navigationController?.viewControllers.count ?? 0 > 1 {
                    _ = self.navigationController?.popToRootViewController(animated: true)
                    }
                }
            }
            
            if topTabsVisible {
                updateViewController.preferredContentSize = CGSize(width: ViewControllerConsts.PreferredSize.UpdateViewController.width, height: ViewControllerConsts.PreferredSize.UpdateViewController.height)
                updateViewController.modalPresentationStyle = .formSheet
            } else {
                updateViewController.modalPresentationStyle = .fullScreen
            }
            
            // On iPad we present it modally in a controller
            present(updateViewController, animated: animated) {
                // On first run (and forced) open up the homepage in the background.
                if let homePageURL = NewTabHomePageAccessors.getHomePage(), let tab = self.tabManager.selectedTab, DeviceInfo.hasConnectivity() {
                    tab.loadRequest(URLRequest(url: homePageURL))
                }
            }

            return true
        }
        
        return false
    }
    
    private func showProperIntroVC() {
        let introViewController = IntroViewController()

        introViewController.didFinishClosure = { controller in
            Defaults[.introSeen] = true
            controller.dismiss(animated: true) {
                if self.navigationController?.viewControllers.count ?? 0 > 1 {
                    _ = self.navigationController?.popToRootViewController(animated: true)
                }
            }
        }

        introViewController.visitHomePage = visitHomePage
        introViewController.visitSigninPage = visitSigninPage

        self.introVCPresentHelper(introViewController: introViewController)
    }

    private func visitHomePage() {
        if let tab = self.tabManager.selectedTab, DeviceInfo.hasConnectivity() {
            tab.loadRequest(URLRequest(url: NeevaConstants.appSignupURL))
        }
    }

    private func visitSigninPage() {
        if let tab = self.tabManager.selectedTab, DeviceInfo.hasConnectivity() {
            tab.loadRequest(URLRequest(url: NeevaConstants.appSigninURL))
        }
    }
    
    private func introVCPresentHelper(introViewController: UIViewController) {
        // On iPad we present it modally in a controller
        if topTabsVisible {
            introViewController.preferredContentSize = CGSize(width: ViewControllerConsts.PreferredSize.IntroViewController.width, height: ViewControllerConsts.PreferredSize.IntroViewController.height)
            introViewController.modalPresentationStyle = .formSheet
        } else {
            introViewController.modalPresentationStyle = .fullScreen
        }
        present(introViewController, animated: true)
    }


}

extension BrowserViewController: ContextMenuHelperDelegate {
    func contextMenuHelper(_ contextMenuHelper: ContextMenuHelper, didLongPressElements elements: ContextMenuHelper.Elements, gestureRecognizer: UIGestureRecognizer) {
        // locationInView can return (0, 0) when the long press is triggered in an invalid page
        // state (e.g., long pressing a link before the document changes, then releasing after a
        // different page loads).
        let touchPoint = gestureRecognizer.location(in: view)
        guard touchPoint != CGPoint.zero else { return }

        let touchSize = CGSize(width: 0, height: 16)

        let actionSheetController = AlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        var dialogTitle: String?

        if let url = elements.link, let currentTab = tabManager.selectedTab {
            dialogTitle = url.absoluteString
            let isPrivate = currentTab.isPrivate
            screenshotHelper.takeDelayedScreenshot(currentTab)

            let addTab = { (rURL: URL, isPrivate: Bool) in
                    let tab = self.tabManager.addTab(URLRequest(url: rURL as URL), afterTab: currentTab, isPrivate: isPrivate)
                    guard !self.topTabsVisible else {
                        return
                    }
                    // We're not showing the top tabs; show a toast to quick switch to the fresh new tab.
                    let toast = ButtonToast(labelText: Strings.ContextMenuButtonToastNewTabOpenedLabelText, buttonText: Strings.ContextMenuButtonToastNewTabOpenedButtonText, completion: { buttonPressed in
                        if buttonPressed {
                            self.tabManager.selectTab(tab)
                        }
                    })
                    self.show(toast: toast)
            }

            if !isPrivate {
                let openNewTabAction = UIAlertAction(title: Strings.ContextMenuOpenInNewTab, style: .default) { _ in
                    addTab(url, false)
                }
                actionSheetController.addAction(openNewTabAction, accessibilityIdentifier: "linkContextMenu.openInNewTab")
            }

            let openNewPrivateTabAction = UIAlertAction(title: Strings.ContextMenuOpenInNewIncognitoTab, style: .default) { _ in
                addTab(url, true)
            }
            actionSheetController.addAction(openNewPrivateTabAction, accessibilityIdentifier: "linkContextMenu.openInNewPrivateTab")

    
            let downloadAction = UIAlertAction(title: Strings.ContextMenuDownloadLink, style: .default) { _ in
                // This checks if download is a blob, if yes, begin blob download process
                if !DownloadContentScript.requestBlobDownload(url: url, tab: currentTab) {
                    //if not a blob, set pendingDownloadWebView and load the request in the webview, which will trigger the WKWebView navigationResponse delegate function and eventually downloadHelper.open()
                    self.pendingDownloadWebView = currentTab.webView
                    let request = URLRequest(url: url)
                    currentTab.webView?.load(request)
                }
            }
            actionSheetController.addAction(downloadAction, accessibilityIdentifier: "linkContextMenu.download")

            let copyAction = UIAlertAction(title: Strings.ContextMenuCopyLink, style: .default) { _ in
                UIPasteboard.general.url = url as URL
            }
            actionSheetController.addAction(copyAction, accessibilityIdentifier: "linkContextMenu.copyLink")

            let shareAction = UIAlertAction(title: Strings.ContextMenuShareLink, style: .default) { _ in
                self.presentActivityViewController(url as URL, sourceView: self.view, sourceRect: CGRect(origin: touchPoint, size: touchSize), arrowDirection: .any)
            }
            actionSheetController.addAction(shareAction, accessibilityIdentifier: "linkContextMenu.share")
        }

        if let url = elements.image {
            if dialogTitle == nil {
                dialogTitle = elements.title ?? url.absoluteString
            }

            let saveImageAction = UIAlertAction(title: Strings.ContextMenuSaveImage, style: .default) { _ in
                self.getImageData(url) { data in
                    guard let image = UIImage(data: data) else { return }
                    self.writeToPhotoAlbum(image: image)
                }
            }
            actionSheetController.addAction(saveImageAction, accessibilityIdentifier: "linkContextMenu.saveImage")

            let copyAction = UIAlertAction(title: Strings.ContextMenuCopyImage, style: .default) { _ in
                // put the actual image on the clipboard
                // do this asynchronously just in case we're in a low bandwidth situation
                let pasteboard = UIPasteboard.general
                pasteboard.url = url as URL
                let changeCount = pasteboard.changeCount
                let application = UIApplication.shared
                var taskId = UIBackgroundTaskIdentifier(rawValue: 0)
                taskId = application.beginBackgroundTask(expirationHandler: {
                    application.endBackgroundTask(taskId)
                })

                makeURLSession(userAgent: UserAgent.getUserAgent(), configuration: URLSessionConfiguration.default).dataTask(with: url) { (data, response, error) in
                    guard let _ = validatedHTTPResponse(response, statusCode: 200..<300) else {
                        application.endBackgroundTask(taskId)
                        return
                    }

                    // Only set the image onto the pasteboard if the pasteboard hasn't changed since
                    // fetching the image; otherwise, in low-bandwidth situations,
                    // we might be overwriting something that the user has subsequently added.
                    if changeCount == pasteboard.changeCount, let imageData = data, error == nil {
                        pasteboard.addImageWithData(imageData, forURL: url)
                    }

                    application.endBackgroundTask(taskId)
                }.resume()

            }
            actionSheetController.addAction(copyAction, accessibilityIdentifier: "linkContextMenu.copyImage")

            let copyImageLinkAction = UIAlertAction(title: Strings.ContextMenuCopyImageLink, style: .default) { _ in
                UIPasteboard.general.url = url as URL
            }
            actionSheetController.addAction(copyImageLinkAction, accessibilityIdentifier: "linkContextMenu.copyImageLink")
        }

        let setupPopover = { [unowned self] in
            // If we're showing an arrow popup, set the anchor to the long press location.
            if let popoverPresentationController = actionSheetController.popoverPresentationController {
                popoverPresentationController.sourceView = self.view
                popoverPresentationController.sourceRect = CGRect(origin: touchPoint, size: touchSize)
                popoverPresentationController.permittedArrowDirections = .any
                popoverPresentationController.delegate = self
            }
        }
        setupPopover()

        if actionSheetController.popoverPresentationController != nil {
            displayedPopoverController = actionSheetController
            updateDisplayedPopoverProperties = setupPopover
        }

        if let dialogTitle = dialogTitle {
            if let _ = dialogTitle.asURL {
                actionSheetController.title = dialogTitle.ellipsize(maxLength: ActionSheetTitleMaxLength)
            } else {
                actionSheetController.title = dialogTitle
            }
        }

        let cancelAction = UIAlertAction(title: Strings.CancelString, style: UIAlertAction.Style.cancel, handler: nil)
        actionSheetController.addAction(cancelAction)
        self.present(actionSheetController, animated: true, completion: nil)
    }

    fileprivate func getImageData(_ url: URL, success: @escaping (Data) -> Void) {
        makeURLSession(userAgent: UserAgent.getUserAgent(), configuration: URLSessionConfiguration.default).dataTask(with: url) { (data, response, error) in
            if let _ = validatedHTTPResponse(response, statusCode: 200..<300), let data = data {
                success(data)
            }
        }.resume()
    }

    func contextMenuHelper(_ contextMenuHelper: ContextMenuHelper, didCancelGestureRecognizer: UIGestureRecognizer) {
        displayedPopoverController?.dismiss(animated: true) {
            self.displayedPopoverController = nil
        }
    }
    
    //Support for CMD+ Click on link to open in a new tab
     override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
         super.pressesBegan(presses, with: event)
         if #available(iOS 13.4, *) {
             guard let key = presses.first?.key, (key.keyCode == .keyboardLeftGUI || key.keyCode == .keyboardRightGUI) else { return } //GUI buttons = CMD buttons on ipad/mac
             self.isCmdClickForNewTab = true
         }
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        if #available(iOS 13.4, *) {
            guard let key = presses.first?.key, (key.keyCode == .keyboardLeftGUI || key.keyCode == .keyboardRightGUI) else { return }
            self.isCmdClickForNewTab = false
        }
    }
}

extension BrowserViewController {
    @objc func image(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) {
    }
}

extension BrowserViewController: KeyboardHelperDelegate {
    func keyboardHelper(_ keyboardHelper: KeyboardHelper, keyboardWillShowWithState state: KeyboardState) {
        keyboardState = state
        updateViewConstraints()

        state.animateAlongside {
            self.alertStackView.layoutIfNeeded()
        }
    }

    func keyboardHelper(_ keyboardHelper: KeyboardHelper, keyboardDidShowWithState state: KeyboardState) {

    }

    func keyboardHelper(_ keyboardHelper: KeyboardHelper, keyboardWillHideWithState state: KeyboardState) {
        keyboardState = nil
        updateViewConstraints()

        state.animateAlongside {
            self.alertStackView.layoutIfNeeded()
        }
    }
}

extension BrowserViewController: SessionRestoreHelperDelegate {
    func sessionRestoreHelper(_ helper: SessionRestoreHelper, didRestoreSessionForTab tab: Tab) {
        tab.restoring = false

        if let tab = tabManager.selectedTab, tab.webView === tab.webView {
            updateUIForReaderHomeStateForTab(tab)
        }

        clipboardBarDisplayHandler?.didRestoreSession()
    }
}

extension BrowserViewController: TabTrayDelegate {
    // This function animates and resets the tab chrome transforms when
    // the tab tray dismisses.
    func tabTrayDidDismiss(_ tabTray: TabTrayControllerV1) {
        resetBrowserChrome()
    }
    
    func tabTrayDidAddTab(_ tabTray: TabTrayControllerV1, tab: Tab) {}
    
    func tabTrayDidAddToReadingList(_ tab: Tab) -> ReadingListItem? {
        guard let url = tab.url?.absoluteString, !url.isEmpty else { return nil }
        return profile.readingList.createRecordWithURL(url, title: tab.title ?? url, addedBy: UIDevice.current.name).value.successValue
    }

    func tabTrayDidTapLocationBar(_ tabTray: TabTrayControllerV1) {
        legacyURLBar.tabLocationViewDidTapLocation(legacyURLBar.legacyLocationView)
    }

    func tabTrayRequestsPresentationOf(_ viewController: UIViewController) {
        self.present(viewController, animated: false, completion: nil)
    }
}

// MARK: Browser Chrome Theming
extension BrowserViewController: Themeable {
    func applyTheme() {
        guard self.isViewLoaded else { return }
        let ui: [Themeable?] = [readerModeBar, searchController, libraryViewController, libraryDrawerViewController]
        ui.forEach { $0?.applyTheme() }
        statusBarOverlay.backgroundColor = shouldShowTopTabsForTraitCollection(traitCollection) ? UIColor.Photon.Grey80 : legacyURLBar.backgroundColor
        setNeedsStatusBarAppearanceUpdate()

        (presentedViewController as? Themeable)?.applyTheme()

        // Update the `background-color` of any blank webviews.
        let webViews = tabManager.tabs.compactMap({ $0.webView as? TabWebView })
        webViews.forEach({ $0.applyTheme() })

        let tabs = tabManager.tabs
        tabs.forEach {
            $0.applyTheme()
            legacyURLBar.legacyLocationView.tabDidChangeContentBlocking($0)
        }
        
        guard let contentScript = self.tabManager.selectedTab?.getContentScript(name: ReaderMode.name()) else { return }
        appyThemeForPreferences(contentScript: contentScript)
    }
}

extension BrowserViewController: JSPromptAlertControllerDelegate {
    func promptAlertControllerDidDismiss(_ alertController: JSPromptAlertController) {
        showQueuedAlertIfAvailable()
    }
}

extension BrowserViewController: TopTabsDelegate {
    func topTabsDidPressTabs() {
        libraryDrawerViewController?.close(immediately: true)
        legacyURLBar.leaveOverlayMode(didCancel: true)
        self.urlBarDidPressTabs(legacyURLBar)
    }

    func topTabsDidPressNewTab(_ isPrivate: Bool) {
        libraryDrawerViewController?.close(immediately: true)
        openBlankNewTab(focusLocationField: false, isPrivate: isPrivate)
    }

    func topTabsDidTogglePrivateMode() {
        libraryDrawerViewController?.close(immediately: true)
        guard let _ = tabManager.selectedTab else {
            return
        }
        legacyURLBar.leaveOverlayMode()
    }

    func topTabsDidChangeTab() {
        libraryDrawerViewController?.close()
        legacyURLBar.leaveOverlayMode(didCancel: true)
    }
}

extension BrowserViewController {
    public static func foregroundBVC() -> BrowserViewController {
//        if #available(iOS 13.0, *) {
//            for scene in UIApplication.shared.connectedScenes {
//                if scene.activationState == .foregroundActive, let sceneDelegate = ((scene as? UIWindowScene)?.delegate as? UIWindowSceneDelegate) {
//                    return sceneDelegate.window!!.rootViewController as! BrowserViewController
//                }
//            }
//        }
        
        return (UIApplication.shared.delegate as! AppDelegate).browserViewController
    }
}

extension BrowserViewController {
    func showAddToSpacesSheet(url: URL, title: String?, webView: WKWebView) {
        webView.evaluateJavaScript("document.querySelector('meta[name=\"description\"]').content") { (result, error) in
            let title = (title ?? "").isEmpty ? url.absoluteString : title!
            let request = AddToSpaceRequest(title: title, description: result as? String, url: url)
            self.showOverlaySheetViewController(
                AddToSpaceViewController(
                    request: request,
                    onDismiss: {
                        self.hideOverlaySheetViewController()
                        if request.state != .initial {
                            self.show(toast: AddToSpaceToast(request: request, onOpenSpace: { spaceID in
                                self.openURLInNewTab(NeevaConstants.appSpacesURL / spaceID)
                            }))
                        }
                    },
                    onOpenURL: { url in
                        self.hideOverlaySheetViewController()
                        self.openURLInNewTab(url)
                    }))
        }
    }
}

extension BrowserViewController {

    func screenshot() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(view.window!.bounds.size, true, 0)
        defer { UIGraphicsEndImageContext() }

        if !view.window!.drawHierarchy(in: view.window!.bounds, afterScreenUpdates: false) {
            // ???
            print("failed to draw hierarchy")
        }
        return UIGraphicsGetImageFromCurrentImageContext()

    }

    func showNeevaMenuSheet() {
        let isPrivate = tabManager.selectedTab?.isPrivate ?? false
        let image = screenshot()

        self.showOverlaySheetViewController(
            NeevaMenuViewController(delegate: self, onDismiss: {
                self.hideOverlaySheetViewController()
                self.isNeevaMenuSheetOpen = false
            }, isPrivate: isPrivate, feedbackImage: image)
        )
    }

    func hideNeevaMenuSheet() {
        self.hideOverlaySheetViewController()
    }
}
