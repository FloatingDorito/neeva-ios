// Copyright Neeva. All rights reserved.

import Combine
import Defaults
import Shared
import Storage
import SwiftUI

protocol ZeroQueryPanelDelegate: AnyObject {
    func zeroQueryPanelDidRequestToOpenInNewTab(_ url: URL, isPrivate: Bool)
    func zeroQueryPanel(didSelectURL url: URL, visitType: VisitType)
    func zeroQueryPanel(didEnterQuery query: String)
    func zeroQueryPanelDidRequestToSaveToSpace(_ url: URL, title: String?, description: String?)
}

enum ZeroQueryOpenedLocation: Equatable {
    case tabTray
    case openTab(Tab?)
    case createdTab
    case backButton
    case newTabButton

    var openedTab: Tab? {
        switch self {
        case .openTab(let tab):
            return tab
        default:
            return nil
        }
    }
}

enum ZeroQueryTarget {
    /// Navigate the current tab.
    case currentTab

    /// Navigate to an existing tab matching the URL or create a new tab.
    case existingOrNewTab

    /// Navigate in a new tab.
    case newTab

    static var defaultValue: ZeroQueryTarget = .existingOrNewTab
}

class ZeroQueryModel: ObservableObject {
    @Published var isPrivate = false
    @Published var promoCard: PromoCardType?
    @Published var showRatingsCard: Bool = false
    @Published var openedFrom: ZeroQueryOpenedLocation?

    var tabURL: URL? {
        if case .openTab(let tab) = openedFrom, let url = tab?.url {
            return url
        }

        return nil
    }

    var searchQuery: String? {
        if let url = tabURL, url.isNeevaURL() {
            return neevaSearchEngine.queryForSearchURL(url)
        }

        return nil
    }

    let bvc: BrowserViewController

    @ObservedObject var suggestedSitesViewModel: SuggestedSitesViewModel = SuggestedSitesViewModel(
        sites: [])
    let profile: Profile
    let shareURLHandler: (URL, UIView) -> Void
    var delegate: ZeroQueryPanelDelegate?
    var isLazyTab = false
    var targetTab: ZeroQueryTarget = .defaultValue

    init(
        bvc: BrowserViewController, profile: Profile,
        shareURLHandler: @escaping (URL, UIView) -> Void
    ) {
        self.bvc = bvc
        self.profile = profile
        self.shareURLHandler = shareURLHandler
        updateState()
        profile.panelDataObservers.activityStream.refreshIfNeeded(forceTopSites: true)
    }

    func signIn() {
        self.bvc.presentIntroViewController(true) {
            self.bvc.hideZeroQuery()
        }
    }

    func handleReferralPromo() {
        // log click referral promo from zero query page
        var attributes = EnvironmentHelper.shared.getAttributes()
        attributes.append(ClientLogCounterAttribute(key: "source", value: "zero query"))
        ClientLogger.shared.logCounter(
            .OpenReferralPromo, attributes: attributes)
        self.delegate?.zeroQueryPanel(
            didSelectURL: NeevaConstants.appReferralsURL,
            visitType: .bookmark)
    }

    func updateState() {
        isPrivate = bvc.tabManager.isIncognito

        // TODO: remove once all users have upgraded
        if UserDefaults.standard.bool(forKey: "DidDismissDefaultBrowserCard") {
            UserDefaults.standard.removeObject(forKey: "DidDismissDefaultBrowserCard")
            Defaults[.didDismissDefaultBrowserCard] = true
        }

        if !Defaults[.signedInOnce] {
            if Defaults[.didFirstNavigation] {
                promoCard = .previewModeSignUp {
                    ClientLogger.shared.logCounter(
                        .PreviewModePromoSignup,
                        attributes: EnvironmentHelper.shared.getFirstRunAttributes())
                    self.signIn()
                }
            } else {
                promoCard = nil
            }
        } else if NeevaFeatureFlags[.referralPromo] && !Defaults[.didDismissReferralPromoCard] {
            promoCard = .referralPromo {
                self.handleReferralPromo()
            } onClose: {
                // log closing referral promo from zero query
                var attributes = EnvironmentHelper.shared.getAttributes()
                attributes.append(ClientLogCounterAttribute(key: "source", value: "zero query"))
                ClientLogger.shared.logCounter(
                    .CloseReferralPromo, attributes: attributes)
                self.promoCard = nil
                Defaults[.didDismissReferralPromoCard] = true
            }
        } else if !NeevaUserInfo.shared.hasLoginCookie() {
            promoCard = .neevaSignIn {
                ClientLogger.shared.logCounter(
                    .PromoSignin, attributes: EnvironmentHelper.shared.getFirstRunAttributes())
                self.signIn()
            }
        } else if !Defaults[.seenBlackFridayFollowPromo]
            && NeevaFeatureFlags.latestValue(.enableBlackFridayPromoCard)
            && !SpaceStore.shared.allSpaces.contains(where: {
                $0.id.id == SpaceStore.promotionalSpaceId
            })
        {
            promoCard = .blackFridayFollowPromo(
                action: {
                    ClientLogger.shared.logCounter(
                        .BlackFridayPromo)
                    let spaceId = SpaceStore.promotionalSpaceId
                    let gridModel = self.bvc.cardGridViewController.gridModel
                    gridModel.openSpace(
                        spaceId: spaceId, bvc: self.bvc,
                        completion: {
                            self.bvc.hideZeroQuery()
                            self.promoCard = nil
                        }
                    )
                },
                onClose: {
                    ClientLogger.shared.logCounter(
                        .CloseBlackFridayPromo)
                    Defaults[.seenBlackFridayFollowPromo] = true
                    self.promoCard = nil
                })
        } else if !Defaults[.didDismissDefaultBrowserCard] {
            promoCard = .defaultBrowser {
                ClientLogger.shared.logCounter(
                    .PromoDefaultBrowser, attributes: EnvironmentHelper.shared.getAttributes())
                self.bvc.presentDBOnboardingViewController()

                // Set default browser onboarding did show to true so it will not show again after user clicks this button
                Defaults[.didShowDefaultBrowserOnboarding] = true
            } onClose: {
                ClientLogger.shared.logCounter(
                    .CloseDefaultBrowserPromo, attributes: EnvironmentHelper.shared.getAttributes())
                self.promoCard = nil
                Defaults[.didDismissDefaultBrowserCard] = true
            }
        } else {
            promoCard = nil
        }

        // In case the ratings card server update was unsuccessful: each time we enter a ZeroQueryPage, check whether local change has been synced to server
        // The check is only performed once the local ratings card has been hidden
        if Defaults[.ratingsCardHidden] && UserFlagStore.shared.state == .ready
            && !UserFlagStore.shared.hasFlag(.dismissedRatingPromo)
        {
            UserFlagStore.shared.setFlag(.dismissedRatingPromo, action: {})
        }

        showRatingsCard =
            NeevaFeatureFlags[.appStoreRatingPromo]
            && promoCard == nil
            && Defaults[.loginLastWeekTimeStamp].count == 3
            && (!Defaults[.ratingsCardHidden]
                || (UserFlagStore.shared.state == .ready
                    && !UserFlagStore.shared.hasFlag(.dismissedRatingPromo)))

        if showRatingsCard {
            ClientLogger.shared.logCounter(.RatingsRateExperience)
        }
    }

    func updateSuggestedSites() {
        DispatchQueue.main.async {
            TopSitesHandler.getTopSites(
                profile: self.profile
            ).uponQueue(.main) { result in
                self.suggestedSitesViewModel.sites = Array(result.prefix(7))
            }
        }
    }

    func hideURLFromTopSites(_ site: Site) {
        guard let host = site.tileURL.normalizedHost else {
            return
        }
        let url = site.tileURL
        // if the default top sites contains the siteurl. also wipe it from default suggested sites.
        if TopSitesHandler.defaultTopSites().filter({ $0.url == url }).isEmpty == false {
            Defaults[.deletedSuggestedSites].append(url.absoluteString)
        }
        profile.history.removeHostFromTopSites(host).uponQueue(.main) { result in
            guard result.isSuccess else { return }
            self.profile.panelDataObservers.activityStream.refreshIfNeeded(forceTopSites: true)
            self.updateSuggestedSites()
        }
    }

    @discardableResult public func promoteToRealTabIfNecessary(
        url: URL, tabManager: TabManager, searchQuery: String?, visitType: VisitType? = nil
    ) -> Bool {
        guard isLazyTab, targetTab != .existingOrNewTab else {
            return false
        }
        // TODO(darin): Refactor with BVC.finishEditingAndSubmit to simplify logic.
        let tab = tabManager.addTab(URLRequest(url: url), isPrivate: isPrivate, visitType: visitType)
        tabManager.select(tab)
        reset(bvc: nil, createdLazyTab: true)

        tab.queryForNavigation.currentSearchQuery = searchQuery

        return true
    }

    public func reset(bvc: BrowserViewController?, createdLazyTab: Bool = false) {
        if let bvc = bvc, bvc.tabManager.isIncognito, !(bvc.tabManager.privateTabs.count > 0),
            isLazyTab && !createdLazyTab
                && (openedFrom != .tabTray)
        {
            bvc.cardGridViewController.toolbarModel.onToggleIncognito()
        }

        // This can occur if a taps back and the Suggestion UI is shown.
        // If the user cancels out of that UI, we should navigate the tab back, like a complete undo.
        if let bvc = bvc, openedFrom == .backButton {
            bvc.tabManager.selectedTab?.webView?.goBack()
        }

        isLazyTab = false
        openedFrom = nil
        targetTab = .defaultValue
    }
}
