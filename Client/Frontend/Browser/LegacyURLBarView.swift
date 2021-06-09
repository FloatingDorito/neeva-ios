/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Shared
import SnapKit
import Storage

private struct LegacyURLBarViewUX {
    static let TextFieldBorderColor = UIColor.Photon.Grey40
    static let TextFieldActiveBorderColor = UIColor.Photon.Blue40

    static let LocationEdgePadding: CGFloat = 8
    static let LocationOverlayLeftPadding: CGFloat = 14
    static let LocationOverlayRightPadding: CGFloat = 2
    static let Padding: CGFloat = 5.5
    static let ButtonPadding: CGFloat = 12
    static let LocationHeight: CGFloat = UIConstants.TextFieldHeight
    static let ButtonSize: CGFloat = 44  // width and height
    static let TextFieldCornerRadius: CGFloat = UIConstants.TextFieldHeight / 2
    static let ProgressBarHeight: CGFloat = 3
    static let ToolbarEdgePaddding: CGFloat = 24
}

protocol LegacyURLBarDelegate: AnyObject {
    func urlBarDidPressTabs(_ urlBar: LegacyURLBarView)
    func urlBarDidPressReaderMode(_ urlBar: LegacyURLBarView)
    /// - returns: whether the long-press was handled by the delegate; i.e. return `false` when the conditions for even starting handling long-press were not satisfied
    func urlBarDidLongPressReaderMode(_ urlBar: LegacyURLBarView) -> Bool
    func urlBarReloadMenu(_ urlBar: LegacyURLBarView, from button: UIButton) -> UIMenu?
    func urlBarDidPressStop(_ urlBar: LegacyURLBarView)
    func urlBarDidPressReload(_ urlBar: LegacyURLBarView)
    func urlBarDidEnterOverlayMode(_ urlBar: LegacyURLBarView)
    func urlBarDidLeaveOverlayMode(_ urlBar: LegacyURLBarView)
    func urlBarDidLongPressLocation(_ urlBar: LegacyURLBarView)
    func urlBarNeevaMenu(_ urlBar: LegacyURLBarView, from button: UIButton)
    func urlBarDidTapShield(_ urlBar: LegacyURLBarView, from button: UIButton)
    func urlBarLocationAccessibilityActions(_ urlBar: LegacyURLBarView) -> [UIAccessibilityCustomAction]?
    func urlBarDidPressScrollToTop(_ urlBar: LegacyURLBarView)
    func urlBar(_ urlBar: LegacyURLBarView, didRestoreText text: String)
    func urlBar(_ urlBar: LegacyURLBarView, didEnterText text: String)
    func urlBar(_ urlBar: LegacyURLBarView, didSubmitText text: String)
    func urlBarDidBeginDragInteraction(_ urlBar: LegacyURLBarView)
}

class LegacyURLBarView: UIView {
    // Additional UIAppearance-configurable properties
    @objc dynamic var locationBorderColor: UIColor = LegacyURLBarViewUX.TextFieldBorderColor {
        didSet {
            if !inOverlayMode {
                locationContainer.layer.borderColor = locationBorderColor.cgColor
            }
        }
    }
    @objc dynamic var locationActiveBorderColor: UIColor = LegacyURLBarViewUX.TextFieldActiveBorderColor {
        didSet {
            if inOverlayMode {
                locationContainer.layer.borderColor = locationActiveBorderColor.cgColor
            }
        }
    }

    weak var delegate: LegacyURLBarDelegate?
    weak var tabToolbarDelegate: TabToolbarDelegate?
    var lensOrBang: ActiveLensBangInfo?
    var helper: TabToolbarHelper?
    var isTransitioning: Bool = false {
        didSet {
            if isTransitioning {
                // Cancel any pending/in-progress animations related to the progress bar
                self.progressBar.setProgress(1, animated: false)
                self.progressBar.alpha = 0.0
            }
        }
    }

    var toolbarIsShowing = false
    var topTabsIsShowing = false

    fileprivate var locationTextField: ToolbarTextField?

    /// Overlay mode is the state where the lock/reader icons are hidden, the home panels are shown,
    /// and the Cancel button is visible (allowing the user to leave overlay mode). Overlay mode
    /// is *not* tied to the location text field's editing state; for instance, when selecting
    /// a panel, the first responder will be resigned, yet the overlay mode UI is still active.
    var inOverlayMode = false

    private var isPrivateMode = false

    lazy var neevaMenuIcon = UIImage.originalImageNamed("neevaMenuIcon")
    lazy var neevaMenuButton: UIButton = {
        let neevaMenuButton = UIButton(frame: .zero)
        neevaMenuButton.setImage(neevaMenuIcon, for: .normal)
        neevaMenuButton.adjustsImageWhenHighlighted = false
        neevaMenuButton.isAccessibilityElement = true
        neevaMenuButton.isHidden = false
        neevaMenuButton.imageView?.contentMode = .left
        neevaMenuButton.accessibilityLabel = .TabLocationPageOptionsAccessibilityLabel
        neevaMenuButton.accessibilityIdentifier = "URLBarView.neevaMenuButton"
        neevaMenuButton.addTarget(self, action: #selector(didClickNeevaMenu), for: UIControl.Event.touchUpInside)
        neevaMenuButton.showsMenuAsPrimaryAction = true
        return neevaMenuButton
    }()
    
    lazy var locationView: TabLocationView = {
        let locationView = TabLocationView()
        locationView.layer.cornerRadius = LegacyURLBarViewUX.TextFieldCornerRadius
        locationView.translatesAutoresizingMaskIntoConstraints = false
        locationView.delegate = self
        return locationView
    }()

    lazy var locationContainer: UIView = {
        let locationContainer = TabLocationContainerView()
        locationContainer.translatesAutoresizingMaskIntoConstraints = false
        locationContainer.backgroundColor = .clear
        return locationContainer
    }()

    let line = UIView()

    lazy var cardsButton: CardStripButton = {
        let cardsButton = CardStripButton()
        return cardsButton
    }()

    lazy var tabsButton: TabsButton = {
        let tabsButton = TabsButton.tabTrayButton()
        tabsButton.accessibilityIdentifier = "URLBarView.tabsButton"
        return tabsButton
    }()

    fileprivate lazy var progressBar: GradientProgressBar = {
        let progressBar = GradientProgressBar()
        progressBar.clipsToBounds = false
        return progressBar
    }()

    fileprivate lazy var cancelButton: UIButton = {
        let cancelButton = InsetButton()
        cancelButton.setTitle(Strings.CancelString, for: .normal)
        cancelButton.setTitleColor(.systemBlue, for: .normal)
        cancelButton.accessibilityIdentifier = "urlBar-cancel"
        cancelButton.accessibilityLabel = Strings.BackTitle
        cancelButton.addTarget(self, action: #selector(didClickCancel), for: .touchUpInside)
        cancelButton.alpha = 0
        cancelButton.isPointerInteractionEnabled = true
        return cancelButton
    }()

    var addToSpacesButton = ToolbarButton()

    var forwardButton = ToolbarButton()
    var shareButton = ToolbarButton()
    var backButton = ToolbarButton()

    var toolbarNeevaMenuButton = ToolbarButton()

    lazy var actionButtons: [ToolbarButton] = [self.addToSpacesButton, self.forwardButton, self.backButton, self.shareButton]

    var currentURL: URL? {
        get {
            return locationView.url as URL?
        }

        set(newURL) {
            locationView.url = newURL
            if let url = newURL, InternalURL(url)?.isAboutHomeURL ?? false {
                line.isHidden = true
            } else {
                line.isHidden = false
            }
        }
    }

    var profile: Profile? = nil
    
    init(profile: Profile) {
        self.profile = profile
        super.init(frame: CGRect())
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    fileprivate func commonInit() {
        locationContainer.addSubview(locationView)

        [line, tabsButton, neevaMenuButton, progressBar, cancelButton, addToSpacesButton,
         forwardButton, backButton, shareButton, locationContainer].forEach {
            addSubview($0)
        }
        if FeatureFlag[.cardStrip] {
            addSubview(cardsButton)
        }

        helper = TabToolbarHelper(toolbar: self)
        setupConstraints()

        // Make sure we hide any views that shouldn't be showing in non-overlay mode.
        updateViewsForOverlayModeAndToolbarChanges()

        // Create LocationTextField and update constraints to layout correctly before hiding it
        createLocationTextField()
        inOverlayMode = true
        updateConstraints()
        locationTextField?.isHidden = true

        inOverlayMode = false
        updateConstraints()

        applyUIMode(isPrivate: isPrivateMode)

        neevaMenuButton.isPointerInteractionEnabled = true
    }
    
    fileprivate func setupConstraints() {

        line.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalTo(self)
            make.height.equalTo(0.5)
        }

        progressBar.snp.makeConstraints { make in
            make.top.equalTo(self.snp.bottom).inset(LegacyURLBarViewUX.ProgressBarHeight / 2)
            make.height.equalTo(LegacyURLBarViewUX.ProgressBarHeight)
            make.left.right.equalTo(self)
        }
        
        locationView.snp.makeConstraints { make in
            make.edges.equalTo(self.locationContainer)
        }
        
        cancelButton.snp.makeConstraints { make in
            make.trailing.equalTo(self.safeArea.trailing).offset(toolbarIsShowing ? -LegacyURLBarViewUX.ToolbarEdgePaddding : -LegacyURLBarViewUX.LocationEdgePadding)
            make.centerY.equalTo(self.locationContainer)
            make.height.equalTo(LegacyURLBarViewUX.ButtonSize)
            make.width.equalTo(cancelButton.intrinsicContentSize.width)
        }

        backButton.snp.makeConstraints { make in
            make.leading.equalTo(self.safeArea.leading).offset(LegacyURLBarViewUX.ToolbarEdgePaddding)
            make.centerY.equalTo(self.locationContainer)
            make.size.equalTo(LegacyURLBarViewUX.ButtonSize)
        }

        forwardButton.snp.makeConstraints { make in
            make.leading.equalTo(self.backButton.snp.trailing).offset(LegacyURLBarViewUX.ButtonPadding)
            make.centerY.equalTo(self.locationContainer)
            make.size.equalTo(LegacyURLBarViewUX.ButtonSize)
        }

        neevaMenuButton.snp.makeConstraints { make in
            make.leading.equalTo(self.forwardButton.snp.trailing).offset(LegacyURLBarViewUX.ButtonPadding)
            make.centerY.equalTo(self.locationContainer)
            make.size.equalTo(LegacyURLBarViewUX.ButtonSize)
        }

        shareButton.snp.makeConstraints { make in
            make.centerY.equalTo(self.locationContainer)
            make.size.equalTo(LegacyURLBarViewUX.ButtonSize)
        }

        addToSpacesButton.snp.makeConstraints { make in
            make.leading.equalTo(self.shareButton.snp.trailing).offset(LegacyURLBarViewUX.ButtonPadding)
            make.centerY.equalTo(self.locationContainer)
            make.size.equalTo(LegacyURLBarViewUX.ButtonSize)
        }

        if FeatureFlag[.cardStrip] {
            cardsButton.snp.makeConstraints { make in
                make.leading.equalTo(self.tabsButton.snp.trailing).offset(LegacyURLBarViewUX.ButtonPadding)
                make.trailing.equalTo(self.safeArea.trailing).offset(-LegacyURLBarViewUX.ToolbarEdgePaddding)
                make.centerY.equalTo(self.locationContainer)
                make.size.equalTo(LegacyURLBarViewUX.ButtonSize)
            }
        }

        tabsButton.snp.makeConstraints { make in
            make.leading.equalTo(self.addToSpacesButton.snp.trailing).offset(LegacyURLBarViewUX.ButtonPadding)
            make.centerY.equalTo(self.locationContainer)
            make.size.equalTo(LegacyURLBarViewUX.ButtonSize)
            if !FeatureFlag[.cardStrip] {
                make.trailing.equalTo(self.safeArea.trailing).offset(-LegacyURLBarViewUX.ToolbarEdgePaddding)
            }
        }
    }

    override func updateConstraints() {
        super.updateConstraints()
        self.locationContainer.snp.remakeConstraints { make in
            if inOverlayMode {
                make.leading.equalTo(self.safeArea.leading).offset(LegacyURLBarViewUX.LocationEdgePadding)
                make.trailing.equalTo(self.cancelButton.snp.leading).offset(-2 * LegacyURLBarViewUX.Padding)
            } else if self.toolbarIsShowing {
                make.leading.equalTo(self.neevaMenuButton.snp.trailing).offset(LegacyURLBarViewUX.Padding)
                make.trailing.equalTo(self.shareButton.snp.leading).offset(-LegacyURLBarViewUX.Padding)
            } else {
                make.leading.equalTo(self.safeArea.leading).offset(LegacyURLBarViewUX.LocationEdgePadding)
                make.trailing.equalTo(self.safeArea.trailing).offset(-LegacyURLBarViewUX.LocationEdgePadding)
            }
            make.height.equalTo(LegacyURLBarViewUX.LocationHeight)
            if self.toolbarIsShowing {
                make.centerY.equalTo(self)
            } else {
                make.top.equalTo(self).offset(UIConstants.TopToolbarPaddingTop)
            }
        }
        if inOverlayMode {
            self.locationTextField?.snp.remakeConstraints { make in
                make.edges.equalTo(self.locationView).inset(
                    UIEdgeInsets(top: 0, left: LegacyURLBarViewUX.LocationOverlayLeftPadding,
                                 bottom: 0, right: LegacyURLBarViewUX.LocationOverlayRightPadding))
            }
        }
    }

    @objc func didClickNeevaMenu() {
        self.delegate?.urlBarNeevaMenu(self, from: neevaMenuButton)
    }

    func createLeftViewFavicon(_ suggestion: String = "") {
        locationTextField.self?.leftViewMode = UITextField.ViewMode.always
        let iconView = UIImageView(frame: CGRect(x: 0, y: 0, width: 20 , height: 20))
        iconView.layer.cornerRadius = 2
        iconView.clipsToBounds = true
        iconView.contentMode = .scaleAspectFill

        let favicons = BrowserViewController.foregroundBVC().tabManager.selectedTab?.favicons
        if let lensOrBang = self.lensOrBang,
           let type = lensOrBang.type {
            iconView.image = UIImage(systemSymbol: type.defaultSymbol)
                .applyingSymbolConfiguration(UIImage.SymbolConfiguration(weight: .medium))?
                .withTintColor(.label, renderingMode: .alwaysOriginal)
        } else if suggestion == NeevaConstants.appHost || suggestion == "https://\(NeevaConstants.appHost)" || (currentURL?.host == NeevaConstants.appHost && suggestion == "") {
            iconView.image = UIImage(named: "neevaMenuIcon")
        } else if (suggestion != "") {
            iconView.image = UIImage(systemName: "globe", withConfiguration: UIImage.SymbolConfiguration(weight: .medium))?.withRenderingMode(.alwaysTemplate).tinted(withColor: UIColor.Neeva.GlobeFavGray)

            let gURL = suggestion.hasPrefix("http") ? URL(string: suggestion)! : URL(string: "https://\(suggestion)")!

            let site = Site(url: gURL.absoluteString, title: "")

            if let appDelegate = UIApplication.shared.delegate as? AppDelegate, let profile = appDelegate.profile {
                profile.favicons.getFaviconImage(forSite: site).uponQueue(.main) { result in
                    guard let image = result.successValue else {
                        return
                    }
                    iconView.image = image.createScaled(PhotonActionSheetUX.FaviconSize)
                }
            }
        } else {
            iconView.image = UIImage(named: "neevaMenuIcon")
            let currentURL = BrowserViewController.foregroundBVC().tabManager.selectedTab?.url
            let currentText = locationTextField?.text

            if currentURL != nil && currentText == "" {
                for fav in favicons! {
                    if (fav.url != "") {
                        let site = Site(url: fav.url, title: "")
                        iconView.setFavicon(forSite: site) {
                            iconView.image = iconView.image?.createScaled(PhotonActionSheetUX.FaviconSize)
                        }
                        break
                    }
                }
            }
        }
        locationTextField.self?.leftView = iconView
    }

    
    func createLocationTextField() {
        guard locationTextField == nil else { return }

        locationTextField = ToolbarTextField()

        guard let locationTextField = locationTextField else { return }

        locationTextField.font = UIFont.systemFont(ofSize: 16)
        locationTextField.backgroundColor = .clear
        locationTextField.adjustsFontForContentSizeCategory = true
        locationTextField.clipsToBounds = true
        locationTextField.translatesAutoresizingMaskIntoConstraints = false
        locationTextField.autocompleteDelegate = self
        locationTextField.keyboardType = .webSearch
        locationTextField.autocorrectionType = .no
        locationTextField.autocapitalizationType = .none
        locationTextField.returnKeyType = .go
        locationTextField.clearButtonMode = .whileEditing
        locationTextField.textAlignment = .left
        locationTextField.accessibilityIdentifier = "address"
        locationTextField.accessibilityLabel = .URLBarLocationAccessibilityLabel

        createLeftViewFavicon()

        locationContainer.addSubview(locationTextField)

        // Disable dragging urls on iPhones because it conflicts with editing the text
        if UIDevice.current.userInterfaceIdiom != .pad {
            locationTextField.textDragInteraction?.isEnabled = false
        }

        locationTextField.applyUIMode(isPrivate: isPrivateMode)
    }

    override func becomeFirstResponder() -> Bool {
        return self.locationTextField?.becomeFirstResponder() ?? false
    }

    func removeLocationTextField() {
        locationTextField?.removeFromSuperview()
        locationTextField = nil
    }

    // Ideally we'd split this implementation in two, one URLBarView with a toolbar and one without
    // However, switching views dynamically at runtime is a difficult. For now, we just use one view
    // that can show in either mode.
    func setShowToolbar(_ shouldShow: Bool) {
        toolbarIsShowing = shouldShow
        setNeedsUpdateConstraints()
        // when we transition from portrait to landscape, calling this here causes
        // the constraints to be calculated too early and there are constraint errors
        if !toolbarIsShowing {
            updateConstraintsIfNeeded()
            locationView.showShareButton = true
        }else {
            locationView.showShareButton = false
        }
        updateViewsForOverlayModeAndToolbarChanges()
    }

    func updateAlphaForSubviews(_ alpha: CGFloat) {
        locationContainer.alpha = alpha
        neevaMenuButton.alpha = alpha
        actionButtons.forEach {
            $0.alpha = alpha
        }
        tabsButton.alpha = alpha
        if FeatureFlag[.cardStrip] {
            cardsButton.alpha = alpha
        }
    }

    func updateProgressBar(_ progress: Float) {
        locationView.reloadButton.reloadButtonState = progress != 1 ? .stop : .reload
        progressBar.alpha = 1
        progressBar.isHidden = false
        progressBar.setProgress(progress, animated: !isTransitioning)
    }

    func hideProgressBar() {
        progressBar.isHidden = true
        progressBar.setProgress(0, animated: false)
    }

    func updateReaderModeState(_ state: ReaderModeState) {
        switch state {
        case .active:
            locationView.reloadButton.isHidden = true
        case .available, .unavailable:
            locationView.reloadButton.isHidden = false
        }
    }

    func setAutocompleteSuggestion(_ suggestion: String?) {
        locationTextField?.setAutocompleteSuggestion(suggestion)
        createLeftViewFavicon(suggestion ?? "")
    }

    func setLocation(_ location: String?, search: Bool) {
        guard let text = location, !text.isEmpty else {
            locationTextField?.text = location
            return
        }
        if search {
            locationTextField?.text = text
            // Not notifying when empty agrees with AutocompleteTextField.textDidChange.
            delegate?.urlBar(self, didRestoreText: text)
        } else {
            locationTextField?.setTextWithoutSearching(text)
        }
    }

    func enterOverlayMode(_ locationText: String?, pasted: Bool, search: Bool) {
        locationTextField?.isHidden = false
        // Show the overlay mode UI, which includes hiding the locationView and replacing it
        // with the editable locationTextField.
        animateToOverlayState(overlayMode: true)

        delegate?.urlBarDidEnterOverlayMode(self)

        // Bug 1193755 Workaround - Calling becomeFirstResponder before the animation happens
        // won't take the initial frame of the label into consideration, which makes the label
        // look squished at the start of the animation and expand to be correct. As a workaround,
        // we becomeFirstResponder as the next event on UI thread, so the animation starts before we
        // set a first responder.
        if pasted {
            // Clear any existing text, focus the field, then set the actual pasted text.
            // This avoids highlighting all of the text.
            self.locationTextField?.text = ""
            DispatchQueue.main.async {
                self.locationTextField?.becomeFirstResponder()
                self.setLocation(locationText, search: search)
            }
        } else {
            DispatchQueue.main.async {
                self.locationTextField?.becomeFirstResponder()
                // Need to set location again so text could be immediately selected.
                self.setLocation(locationText, search: search)
                if !search {
                    self.locationTextField?.selectAll(nil)
                }
            }
        }
    }

    func leaveOverlayMode(didCancel cancel: Bool = false) {
        locationTextField?.resignFirstResponder()
        animateToOverlayState(overlayMode: false, didCancel: cancel)
        delegate?.urlBarDidLeaveOverlayMode(self)
    }

    func prepareOverlayAnimation() {
        // Make sure everything is showing during the transition (we'll hide it afterwards).
        bringSubviewToFront(self.locationContainer)
        cancelButton.isHidden = false
        neevaMenuButton.isHidden = !toolbarIsShowing
        progressBar.isHidden = false
        addToSpacesButton.isHidden = !toolbarIsShowing
        forwardButton.isHidden = !toolbarIsShowing
        backButton.isHidden = !toolbarIsShowing
        tabsButton.isHidden = !toolbarIsShowing
        shareButton.isHidden = !toolbarIsShowing
        if FeatureFlag[.cardStrip] {
            cardsButton.isHidden = !toolbarIsShowing
        }
    }

    func transitionToOverlay(_ didCancel: Bool = false) {
        locationTextField?.leftView?.alpha = inOverlayMode ? 1 : 0
        locationView.contentView.alpha = inOverlayMode ? 0 : 1
        cancelButton.alpha = inOverlayMode ? 1 : 0
        neevaMenuButton.alpha = inOverlayMode ? 0 : 1
        progressBar.alpha = inOverlayMode || didCancel ? 0 : 1
        tabsButton.alpha = inOverlayMode ? 0 : 1
        if FeatureFlag[.cardStrip] {
            cardsButton.alpha = inOverlayMode ? 0 : 1
        }
        addToSpacesButton.alpha = inOverlayMode ? 0 : 1
        forwardButton.alpha = inOverlayMode ? 0 : 1
        backButton.alpha = inOverlayMode ? 0 : 1
        shareButton.alpha = inOverlayMode ? 0 : 1
    }

    func updateViewsForOverlayModeAndToolbarChanges() {
        // This ensures these can't be selected as an accessibility element when in the overlay mode.
        locationView.overrideAccessibility(enabled: !inOverlayMode)

        cancelButton.isHidden = !inOverlayMode
        neevaMenuButton.isHidden = !toolbarIsShowing || inOverlayMode
        progressBar.isHidden = inOverlayMode
        addToSpacesButton.isHidden = !toolbarIsShowing || inOverlayMode
        forwardButton.isHidden = !toolbarIsShowing || inOverlayMode
        backButton.isHidden = !toolbarIsShowing || inOverlayMode
        tabsButton.isHidden = !toolbarIsShowing || inOverlayMode
        if FeatureFlag[.cardStrip] {
            cardsButton.isHidden = !toolbarIsShowing || inOverlayMode
        }
        shareButton.isHidden = !toolbarIsShowing || inOverlayMode
    }

    func animateToOverlayState(overlayMode overlay: Bool, didCancel cancel: Bool = false) {
        prepareOverlayAnimation()
        layoutIfNeeded()

        inOverlayMode = overlay

        if !overlay {
            locationTextField?.isHidden = true
        }

        UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.0, options: [], animations: {
            self.transitionToOverlay(cancel)
            self.updateConstraints()
            self.layoutIfNeeded()
        }, completion: { _ in
            self.updateViewsForOverlayModeAndToolbarChanges()
        })
    }

    func didClickAddTab() {
        delegate?.urlBarDidPressTabs(self)
    }

    @objc func didClickCancel() {
        leaveOverlayMode(didCancel: true)
    }

    @objc func tappedScrollToTopArea() {
        delegate?.urlBarDidPressScrollToTop(self)
    }
}

extension LegacyURLBarView: TabToolbarProtocol {
    func updateBackStatus(_ canGoBack: Bool) {
        backButton.isEnabled = canGoBack
    }

    func updateForwardStatus(_ canGoForward: Bool) {
        forwardButton.isEnabled = canGoForward
    }

    func updatePageStatus(_ isWebPage: Bool) {
        shareButton.isEnabled = isWebPage
        addToSpacesButton.isEnabled = isWebPage && !isPrivateMode
    }

    var access: [Any]? {
        get {
            if inOverlayMode {
                guard let locationTextField = locationTextField else { return nil }
                return [locationTextField, cancelButton]
            } else {
                if toolbarIsShowing {
                    var list = [backButton, forwardButton, neevaMenuButton, locationContainer, shareButton, addToSpacesButton, tabsButton, progressBar, toolbarNeevaMenuButton]
                    if FeatureFlag[.cardStrip] {
                        list.append(cardsButton)
                    }
                    return list
                } else {
                    return [neevaMenuButton, locationContainer, shareButton, progressBar, toolbarNeevaMenuButton]
                }
            }
        }
        set {
            super.accessibilityElements = newValue
        }
    }
}

extension LegacyURLBarView: TabLocationViewDelegate {

    func tabLocationViewDidLongPressReaderMode(_ tabLocationView: TabLocationView) -> Bool {
        return delegate?.urlBarDidLongPressReaderMode(self) ?? false
    }

    func tabLocationViewReloadMenu(_ tabLocationView: TabLocationView) -> UIMenu? {
        delegate?.urlBarReloadMenu(self, from: tabLocationView.reloadButton)
    }

    func tabLocationViewDidTapLocation(_ tabLocationView: TabLocationView) {
        let isSearchQuery = tabLocationView.displayTextIsQuery

        let overlayText: String
        if isSearchQuery {
            overlayText = tabLocationView.displayText
        } else {
            // TODO: Decode punycode hostname.
            overlayText = tabLocationView.url?.absoluteString ?? ""
        }

        enterOverlayMode(overlayText, pasted: false, search: isSearchQuery)
    }

    func tabLocationViewDidLongPressLocation(_ tabLocationView: TabLocationView) {
        delegate?.urlBarDidLongPressLocation(self)
    }

    func tabLocationViewDidTapReload(_ tabLocationView: TabLocationView) {
        let state = locationView.reloadButton.reloadButtonState
        switch state {
        case .reload:
            delegate?.urlBarDidPressReload(self)
        case .stop:
            delegate?.urlBarDidPressStop(self)
        case .disabled:
            // do nothing
            break
        }
    }

    func tabLocationViewDidTabShareButton(_ tabLocationView: TabLocationView) {
        self.helper?.didPressShareButton()
    }

    func tabLocationViewDidTapStop(_ tabLocationView: TabLocationView) {
        delegate?.urlBarDidPressStop(self)
    }

    func tabLocationViewDidTapReaderMode(_ tabLocationView: TabLocationView) {
        delegate?.urlBarDidPressReaderMode(self)
    }
    
    func tabLocationViewLocationAccessibilityActions(_ tabLocationView: TabLocationView) -> [UIAccessibilityCustomAction]? {
        return delegate?.urlBarLocationAccessibilityActions(self)
    }

    func tabLocationViewDidBeginDragInteraction(_ tabLocationView: TabLocationView) {
        delegate?.urlBarDidBeginDragInteraction(self)
    }

    func tabLocationViewDidTapShield(_ tabLocationView: TabLocationView) {
        delegate?.urlBarDidTapShield(self, from: tabLocationView.shieldButton)
    }
}

extension LegacyURLBarView: AutocompleteTextFieldDelegate {
    func autocompleteTextFieldCompletionCleared(_ autocompleteTextField: AutocompleteTextField) {
        createLeftViewFavicon()
    }

    func autocompleteTextFieldShouldReturn(_ autocompleteTextField: AutocompleteTextField) -> Bool {
        guard let text = locationTextField?.text else { return true }
        if !text.trimmingCharacters(in: .whitespaces).isEmpty {
            delegate?.urlBar(self, didSubmitText: text)
            return true
        } else {
            return false
        }
    }

    func autocompleteTextField(_ autocompleteTextField: AutocompleteTextField, didEnterText text: String) {
        delegate?.urlBar(self, didEnterText: text)
        if text.isEmpty  {
            createLeftViewFavicon()
        }
    }

    func autocompleteTextFieldShouldClear(_ autocompleteTextField: AutocompleteTextField) -> Bool {
        delegate?.urlBar(self, didEnterText: "")
        return true
    }

    func autocompleteTextFieldDidCancel(_ autocompleteTextField: AutocompleteTextField) {
        leaveOverlayMode(didCancel: true)
    }

    func autocompletePasteAndGo(_ autocompleteTextField: AutocompleteTextField) {
        if let pasteboardContents = UIPasteboard.general.string {
            self.delegate?.urlBar(self, didSubmitText: pasteboardContents)
        }
    }
}

// MARK: UIAppearance
extension LegacyURLBarView {
    @objc dynamic var cancelTintColor: UIColor? {
        get { return cancelButton.tintColor }
        set { return cancelButton.tintColor = newValue }
    }
}

extension LegacyURLBarView: PrivateModeUI {
    func applyUIMode(isPrivate: Bool) {
        isPrivateMode = isPrivate

        locationView.applyUIMode(isPrivate: isPrivate)
        locationTextField?.applyUIMode(isPrivate: isPrivate)

        if isPrivate {
            neevaMenuButton.setImage(neevaMenuIcon?.withRenderingMode(.alwaysTemplate), for: .normal)
        } else {
            neevaMenuButton.setImage(neevaMenuIcon, for: .normal)
        }

        neevaMenuButton.tintColor = UIColor.URLBar.neevaMenuTint(isPrivateMode)

        cancelTintColor = UIColor.Browser.tint
        backgroundColor = UIColor.Browser.background
        line.backgroundColor = UIColor.Browser.urlBarDivider

        progressBar.setGradientColors(startColor: UIColor.LoadingBar.start(isPrivateMode), endColor: UIColor.LoadingBar.end(isPrivateMode))
    }
}

// We need a subclass so we can setup the shadows correctly
// This subclass creates a strong shadow on the URLBar
class TabLocationContainerView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        let layer = self.layer
        // The container needs is used to clip the text field so we can align the
        // 'clear' button within the rounded corners of the container properly.
        layer.cornerRadius = LegacyURLBarViewUX.TextFieldCornerRadius
        layer.masksToBounds = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ToolbarTextField: AutocompleteTextField {
    private var isPrivateMode = false

    @objc dynamic var clearButtonTintColor: UIColor? {
        didSet {
            // Clear previous tinted image that's cache and ask for a relayout
            tintedClearImage = nil
            setNeedsLayout()
        }
    }

    fileprivate var tintedClearImage: UIImage?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let image = UIImage.templateImageNamed("topTabs-closeTabs") else { return }
        if tintedClearImage == nil {
            if let clearButtonTintColor = clearButtonTintColor {
                tintedClearImage = image.tinted(withColor: clearButtonTintColor)
            } else {
                tintedClearImage = image
            }
        }
        // Since we're unable to change the tint color of the clear image, we need to iterate through the
        // subviews, find the clear button, and tint it ourselves.
        // https://stackoverflow.com/questions/55046917/clear-button-on-text-field-not-accessible-with-voice-over-swift
        if let clearButton = value(forKey: "_clearButton") as? UIButton {
            clearButton.setImage(tintedClearImage, for: [])

        }
    }

    // The default button size is 19x19, make this larger
    override func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        let r = super.clearButtonRect(forBounds: bounds)
        let grow: CGFloat = 16
        let r2 = CGRect(x: r.minX - grow/2, y:r.minY - grow/2, width: r.width + grow, height: r.height + grow)
        return r2
    }
}

extension ToolbarTextField: PrivateModeUI {
    func applyUIMode(isPrivate: Bool) {
        isPrivateMode = isPrivate
        backgroundColor = .clear
        textColor = UIColor.TextField.textAndTint(isPrivate: isPrivateMode)
        clearButtonTintColor = textColor
        textSelectionColor = UIColor.URLBar.textSelectionHighlight(isPrivateMode)
        tintColor = textSelectionColor.textFieldMode

        if isPrivate {
            attributedPlaceholder =
                NSAttributedString(string: .TabLocationURLPlaceholder, attributes: [NSAttributedString.Key.foregroundColor: UIColor.secondaryLabel.darkVariant])
        } else {
            attributedPlaceholder =
                NSAttributedString(string: .TabLocationURLPlaceholder, attributes: [NSAttributedString.Key.foregroundColor: UIColor.secondaryLabel])
        }
    }
}
