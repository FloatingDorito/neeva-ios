// Copyright Neeva. All rights reserved.

import Defaults
import SDWebImage
import Shared
import Storage

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var scene: UIScene?

    private var tabManager: TabManager!
    private var browserViewController: BrowserViewController!
    private var geigerCounter: KMCGeigerCounter?

    var selectedTabUUID: String? {
        let tabManager = SceneDelegate.getTabManager()
        return tabManager.selectedTab?.tabUUID
    }

    // MARK: - Scene state
    func scene(
        _ scene: UIScene, willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        self.scene = scene

        guard let scene = (scene as? UIWindowScene) else { return }

        window = .init(windowScene: scene)
        window?.makeKeyAndVisible()

        setupRootViewController(scene)

        if Defaults[.enableGeigerCounter] {
            startGeigerCounter()
        }

        self.scene(scene, openURLContexts: connectionOptions.urlContexts)

        DispatchQueue.main.async { [self] in
            if let userActivity = connectionOptions.userActivities.first {
                _ = continueSiriIntent(continue: userActivity)
            }

            if let shortcutItem = connectionOptions.shortcutItem {
                handleShortcut(shortcutItem: shortcutItem)
            }
        }
    }

    private func setupRootViewController(_ scene: UIScene) {
        let profile = getAppDelegateProfile()

        self.tabManager = TabManager(profile: profile, scene: scene)
        self.browserViewController = BrowserViewController(profile: profile, tabManager: tabManager)

        browserViewController.edgesForExtendedLayout = []
        browserViewController.restorationIdentifier = NSStringFromClass(BrowserViewController.self)
        browserViewController.restorationClass = AppDelegate.self

        window!.rootViewController = browserViewController

        browserViewController.tabManager.selectedTab?.reload()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        self.scene = scene

        DispatchQueue.main.async {
            if let signInToken = AppClipHelper.retreiveAppClipData() {
                self.handleSignInToken(signInToken)
            }
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        tabManager.preserveTabs()
    }

    // MARK: - URL managment
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // almost always one URL
        guard let url = URLContexts.first?.url,
            let routerpath = NavigationPath(url: url)
        else { return }

        if let _ = Defaults[.appExtensionTelemetryOpenUrl] {
            Defaults[.appExtensionTelemetryOpenUrl] = nil
        }

        DispatchQueue.main.async {
            // This is in case the AppClip sign in URL ends up opening the app
            // Will occur if the app is already installed
            if url.scheme == "https", NeevaConstants.isAppHost(url.host),
                let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                components.path == "/appclip/login",
                let queryItems = components.queryItems,
                let signInToken = queryItems.first(where: { $0.name == "token" })?.value
            {
                self.handleSignInToken(signInToken)
            } else {
                NavigationPath.handle(nav: routerpath, with: self.browserViewController)
            }
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if !continueSiriIntent(continue: userActivity) {
            _ = checkForUniversalURL(continue: userActivity)
        }
    }

    func continueSiriIntent(continue userActivity: NSUserActivity) -> Bool {
        if let intent = userActivity.interaction?.intent as? OpenURLIntent {
            self.browserViewController.openURLInNewTab(intent.url)
            return true
        }

        if let intent = userActivity.interaction?.intent as? SearchNeevaIntent,
            let query = intent.text,
            let url = neevaSearchEngine.searchURLForQuery(query)
        {
            self.browserViewController.openURLInNewTab(url)
            return true
        }

        return false
    }

    func checkForUniversalURL(continue userActivity: NSUserActivity) -> Bool {
        // Get URL components from the incoming user activity.
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL
        else {
            return false
        }

        self.browserViewController.openURLInNewTab(incomingURL)

        return true
    }

    // MARK: - Shortcut
    func windowScene(
        _ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        handleShortcut(shortcutItem: shortcutItem, completionHandler: completionHandler)
    }

    func handleShortcut(
        shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void = { _ in }
    ) {
        let handledShortCutItem = QuickActions.sharedInstance.handleShortCutItem(
            shortcutItem, withBrowserViewController: BrowserViewController.foregroundBVC())
        completionHandler(handledShortCutItem)
    }

    // MARK: - Get data from current scene
    static func getCurrentSceneDelegate() -> SceneDelegate {
        for scene in UIApplication.shared.connectedScenes {
            if scene.activationState == .foregroundActive
                || UIApplication.shared.connectedScenes.count == 1,
                let sceneDelegate = ((scene as? UIWindowScene)?.delegate as? SceneDelegate)
            {
                return sceneDelegate
            }
        }

        fatalError("Scene Delegate doesn't exist or is nil")
    }

    static func getCurrentScene() -> UIScene {
        if let scene = getCurrentSceneDelegate().scene {
            return scene
        }

        fatalError("Scene doesn't exist or is nil")
    }

    static func getCurrentSceneId() -> String {
        return getCurrentScene().session.persistentIdentifier
    }

    static func getKeyWindow() -> UIWindow {
        if let window = getCurrentSceneDelegate().window {
            return window
        }

        fatalError("Window for current scene is nil")
    }

    public func getBVC() -> BrowserViewController {
        return browserViewController
    }

    static func getTabManager() -> TabManager {
        return getCurrentSceneDelegate().tabManager
    }

    // MARK: - Geiger
    public func startGeigerCounter() {
        if let scene = self.scene as? UIWindowScene {
            geigerCounter = KMCGeigerCounter(windowScene: scene)
        }
    }

    public func stopGeigerCounter() {
        geigerCounter?.disable()
        geigerCounter = nil
    }

    // MARK: - Sign In
    func handleSignInToken(_ signInToken: String) {
        print(signInToken, "sign in token")
        Defaults[.introSeen] = true
        AppClipHelper.saveTokenToDevice(nil)
        browserViewController.openURLInNewTab(
            URL(string: "https://\(NeevaConstants.appHost)/login/qr/finish?q=\(signInToken)")!)

        if let introVC = browserViewController.introViewController {
            introVC.dismiss(animated: true, completion: nil)
        }
    }
}
