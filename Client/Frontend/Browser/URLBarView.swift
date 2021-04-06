/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Shared
import SnapKit

private struct URLBarViewUX {
    static let TextFieldBorderColor = UIColor.Photon.Grey40
    static let TextFieldActiveBorderColor = UIColor.Photon.Blue40

    static let LocationEdgePadding: CGFloat = 16
    static let LocationOverlayLeftPadding: CGFloat = 14
    static let LocationOverlayRightPadding: CGFloat = 2
    static let Padding: CGFloat = 5.5
    static let LocationHeight: CGFloat = UIConstants.TextFieldHeight
    static let ButtonSize: CGFloat = 40  // width and height
    static let TextFieldCornerRadius: CGFloat = UIConstants.TextFieldHeight / 2
    static let ProgressBarHeight: CGFloat = 3
}

protocol URLBarDelegate: AnyObject {
    func urlBarDidPressTabs(_ urlBar: URLBarView)
    func urlBarDidPressReaderMode(_ urlBar: URLBarView)
    /// - returns: whether the long-press was handled by the delegate; i.e. return `false` when the conditions for even starting handling long-press were not satisfied
    func urlBarDidLongPressReaderMode(_ urlBar: URLBarView) -> Bool
    func urlBarReloadMenu(_ urlBar: URLBarView, from button: UIButton) -> UIMenu?
    func urlBarDidPressStop(_ urlBar: URLBarView)
    func urlBarDidPressReload(_ urlBar: URLBarView)
    func urlBarDidEnterOverlayMode(_ urlBar: URLBarView)
    func urlBarDidLeaveOverlayMode(_ urlBar: URLBarView)
    func urlBarDidLongPressLocation(_ urlBar: URLBarView)
    func urlBarNeevaMenu(_ urlBar: URLBarView, from button: UIButton)
    func urlBarDidTapShield(_ urlBar: URLBarView, from button: UIButton)
    func urlBarLocationAccessibilityActions(_ urlBar: URLBarView) -> [UIAccessibilityCustomAction]?
    func urlBarDidPressScrollToTop(_ urlBar: URLBarView)
    func urlBar(_ urlBar: URLBarView, didRestoreText text: String)
    func urlBar(_ urlBar: URLBarView, didEnterText text: String)
    func urlBar(_ urlBar: URLBarView, didSubmitText text: String)
    // Returns either (search query, true) or (url, false).
    func urlBarDisplayTextForURL(_ url: URL?) -> (String?, Bool)
    func urlBarDidBeginDragInteraction(_ urlBar: URLBarView)
}

class URLBarView: UIView {
    // Additional UIAppearance-configurable properties
    @objc dynamic var locationBorderColor: UIColor = URLBarViewUX.TextFieldBorderColor {
        didSet {
            if !inOverlayMode {
                locationContainer.layer.borderColor = locationBorderColor.cgColor
            }
        }
    }
    @objc dynamic var locationActiveBorderColor: UIColor = URLBarViewUX.TextFieldActiveBorderColor {
        didSet {
            if inOverlayMode {
                locationContainer.layer.borderColor = locationActiveBorderColor.cgColor
            }
        }
    }

    weak var delegate: URLBarDelegate?
    weak var tabToolbarDelegate: TabToolbarDelegate?
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

    lazy var neevaMenuIcon = UIImage.originalImageNamed("neevaMenuIcon")
    lazy var neevaMenuButton: UIButton = {
        let neevaMenuButton = UIButton(frame: .zero)
        neevaMenuButton.setImage(neevaMenuIcon, for: .normal)
        neevaMenuButton.adjustsImageWhenHighlighted = false
        neevaMenuButton.isAccessibilityElement = true
        neevaMenuButton.isHidden = false
        neevaMenuButton.imageView?.contentMode = .left
        neevaMenuButton.accessibilityLabel = .TabLocationPageOptionsAccessibilityLabel
        neevaMenuButton.accessibilityIdentifier = "TabLocationView.pageOptionsButton"
        neevaMenuButton.addTarget(self, action: #selector(didClickNeevaMenu), for: UIControl.Event.touchUpInside)
        neevaMenuButton.showsMenuAsPrimaryAction = true
        return neevaMenuButton
    }()
    
    lazy var locationView: TabLocationView = {
        let locationView = TabLocationView()
        locationView.layer.cornerRadius = URLBarViewUX.TextFieldCornerRadius
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

    lazy var tabsButton: TabsButton = {
        let tabsButton = TabsButton.tabTrayButton()
        tabsButton.accessibilityIdentifier = "URLBarView.tabsButton"
        tabsButton.inTopTabs = false
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
        return cancelButton
    }()

    var spacesMenuButton = ToolbarButton()

    var forwardButton = ToolbarButton()
    var shareButton = ToolbarButton()

    var backButton: ToolbarButton = {
        let backButton = ToolbarButton()
        backButton.accessibilityIdentifier = "URLBarView.backButton"
        return backButton
    }()

    lazy var actionButtons: [Themeable & UIButton] = [self.tabsButton, self.spacesMenuButton, self.forwardButton, self.backButton, self.shareButton]

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
    
    fileprivate let privateModeBadge = BadgeWithBackdrop(imageName: "privateModeBadge", backdropCircleColor: UIColor.Defaults.MobilePrivatePurple)
    fileprivate let appMenuBadge = BadgeWithBackdrop(imageName: "menuBadge")
    fileprivate let warningMenuBadge = BadgeWithBackdrop(imageName: "menuWarning", imageMask: "warning-mask")

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

        [line, tabsButton, neevaMenuButton, progressBar, cancelButton, spacesMenuButton,
         forwardButton, backButton, shareButton, locationContainer].forEach {
            addSubview($0)
        }

        privateModeBadge.add(toParent: self)
        appMenuBadge.add(toParent: self)
        warningMenuBadge.add(toParent: self)

        helper = TabToolbarHelper(toolbar: self)
        setupConstraints()

        // Make sure we hide any views that shouldn't be showing in non-overlay mode.
        updateViewsForOverlayModeAndToolbarChanges()
    }
    
    fileprivate func setupConstraints() {

        line.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalTo(self)
            make.height.equalTo(1)
        }

        progressBar.snp.makeConstraints { make in
            make.top.equalTo(self.snp.bottom).inset(URLBarViewUX.ProgressBarHeight / 2)
            make.height.equalTo(URLBarViewUX.ProgressBarHeight)
            make.left.right.equalTo(self)
        }
        
        locationView.snp.makeConstraints { make in
            make.edges.equalTo(self.locationContainer)
        }
        
        cancelButton.snp.makeConstraints { make in
            make.trailing.equalTo(self.safeArea.trailing).offset(-URLBarViewUX.LocationEdgePadding)
            make.centerY.equalTo(self.locationContainer)
            make.height.equalTo(URLBarViewUX.ButtonSize)
            make.width.equalTo(cancelButton.intrinsicContentSize.width)
        }

        backButton.snp.makeConstraints { make in
            make.leading.equalTo(self.safeArea.leading).offset(URLBarViewUX.Padding)
            make.centerY.equalTo(self.locationContainer)
            make.size.equalTo(URLBarViewUX.ButtonSize)
        }

        forwardButton.snp.makeConstraints { make in
            make.leading.equalTo(self.backButton.snp.trailing)
            make.centerY.equalTo(self.locationContainer)
            make.size.equalTo(URLBarViewUX.ButtonSize)
        }

        shareButton.snp.makeConstraints { make in
            make.centerY.equalTo(self.locationContainer)
            make.size.equalTo(URLBarViewUX.ButtonSize)
        }

        spacesMenuButton.snp.makeConstraints { make in
            make.leading.equalTo(self.shareButton.snp.trailing)
            make.centerY.equalTo(self.locationContainer)
            make.size.equalTo(URLBarViewUX.ButtonSize)
        }
        
        tabsButton.snp.makeConstraints { make in
            make.leading.equalTo(self.spacesMenuButton.snp.trailing)
            make.trailing.equalTo(self.safeArea.trailing).offset(-URLBarViewUX.Padding)
            make.centerY.equalTo(self.locationContainer)
            make.size.equalTo(URLBarViewUX.ButtonSize)
        }
        
        privateModeBadge.layout(onButton: tabsButton)
        appMenuBadge.layout(onButton: spacesMenuButton)
        warningMenuBadge.layout(onButton: spacesMenuButton)
    }

    override func updateConstraints() {
        super.updateConstraints()

        self.locationContainer.snp.remakeConstraints { make in
            if inOverlayMode {
                make.leading.equalTo(self.safeArea.leading).offset(URLBarViewUX.LocationEdgePadding)
                make.trailing.equalTo(self.cancelButton.snp.leading).offset(-2 * URLBarViewUX.Padding)
            } else {
                make.leading.equalTo(self.neevaMenuButton.snp.trailing).offset(URLBarViewUX.Padding)
                if self.toolbarIsShowing {
                    make.trailing.equalTo(self.shareButton.snp.leading).offset(-URLBarViewUX.Padding)
                } else {
                    make.trailing.equalTo(self.safeArea.trailing).offset(-URLBarViewUX.LocationEdgePadding)
                }
            }
            make.height.equalTo(URLBarViewUX.LocationHeight)
            if self.toolbarIsShowing {
                make.centerY.equalTo(self)
            } else {
                make.top.equalTo(self).offset(UIConstants.TopToolbarPaddingTop)
            }
        }

        if inOverlayMode {
            self.locationTextField?.snp.remakeConstraints { make in
                make.edges.equalTo(self.locationView).inset(
                    UIEdgeInsets(top: 0, left: URLBarViewUX.LocationOverlayLeftPadding,
                                 bottom: 0, right: URLBarViewUX.LocationOverlayRightPadding))
            }
        } else {
            self.neevaMenuButton.snp.remakeConstraints { make in
                if self.toolbarIsShowing {
                    make.leading.equalTo(self.forwardButton.snp.trailing)
                } else {
                    make.leading.equalTo(self.safeArea.leading).offset(URLBarViewUX.Padding)
                }
                make.centerY.equalTo(self.locationContainer)
                make.size.equalTo(URLBarViewUX.ButtonSize)
            }
        }
    }

    @objc func didClickNeevaMenu() {
        self.delegate?.urlBarNeevaMenu(self, from: neevaMenuButton)
    }
    
    func createLocationTextField() {
        guard locationTextField == nil else { return }

        locationTextField = ToolbarTextField()

        guard let locationTextField = locationTextField else { return }

        locationTextField.font = UIFont.preferredFont(forTextStyle: .body)
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
        locationTextField.attributedPlaceholder = self.locationView.placeholder
        locationContainer.addSubview(locationTextField)

        // Disable dragging urls on iPhones because it conflicts with editing the text
        if UIDevice.current.userInterfaceIdiom != .pad {
            locationTextField.textDragInteraction?.isEnabled = false
        }

        locationTextField.applyTheme()
        locationTextField.backgroundColor = UIColor.theme.textField.backgroundInOverlay
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
        }
        updateViewsForOverlayModeAndToolbarChanges()
    }

    func updateAlphaForSubviews(_ alpha: CGFloat) {
        locationContainer.alpha = alpha
        neevaMenuButton.alpha = alpha
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
        createLocationTextField()

        // Show the overlay mode UI, which includes hiding the locationView and replacing it
        // with the editable locationTextField.
        animateToOverlayState(overlayMode: true)

        delegate?.urlBarDidEnterOverlayMode(self)

        applyTheme()

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
                self.locationTextField?.selectAll(nil)
            }
        }
    }

    func leaveOverlayMode(didCancel cancel: Bool = false) {
        locationTextField?.resignFirstResponder()
        animateToOverlayState(overlayMode: false, didCancel: cancel)
        delegate?.urlBarDidLeaveOverlayMode(self)
        applyTheme()
    }

    func prepareOverlayAnimation() {
        // Make sure everything is showing during the transition (we'll hide it afterwards).
        bringSubviewToFront(self.locationContainer)
        cancelButton.isHidden = false
        neevaMenuButton.isHidden = false
        progressBar.isHidden = false
        spacesMenuButton.isHidden = !toolbarIsShowing
        forwardButton.isHidden = !toolbarIsShowing
        backButton.isHidden = !toolbarIsShowing
        tabsButton.isHidden = !toolbarIsShowing || topTabsIsShowing
        shareButton.isHidden = !toolbarIsShowing
    }

    func transitionToOverlay(_ didCancel: Bool = false) {
        locationView.contentView.alpha = inOverlayMode ? 0 : 1
        cancelButton.alpha = inOverlayMode ? 1 : 0
        neevaMenuButton.alpha = inOverlayMode ? 0 : 1
        progressBar.alpha = inOverlayMode || didCancel ? 0 : 1
        tabsButton.alpha = inOverlayMode ? 0 : 1
        spacesMenuButton.alpha = inOverlayMode ? 0 : 1
        forwardButton.alpha = inOverlayMode ? 0 : 1
        backButton.alpha = inOverlayMode ? 0 : 1
        shareButton.alpha = inOverlayMode ? 0 : 1
    }

    func updateViewsForOverlayModeAndToolbarChanges() {
        // This ensures these can't be selected as an accessibility element when in the overlay mode.
        locationView.overrideAccessibility(enabled: !inOverlayMode)

        cancelButton.isHidden = !inOverlayMode
        neevaMenuButton.isHidden = inOverlayMode
        progressBar.isHidden = inOverlayMode
        spacesMenuButton.isHidden = !toolbarIsShowing || inOverlayMode
        forwardButton.isHidden = !toolbarIsShowing || inOverlayMode
        backButton.isHidden = !toolbarIsShowing || inOverlayMode
        tabsButton.isHidden = !toolbarIsShowing || inOverlayMode || topTabsIsShowing
        shareButton.isHidden = !toolbarIsShowing || inOverlayMode

        // badge isHidden is tied to private mode on/off, use alpha to hide in this case
        [privateModeBadge, appMenuBadge, warningMenuBadge].forEach {
            $0.badge.alpha = (!toolbarIsShowing || inOverlayMode) ? 0 : 1
            $0.backdrop.alpha = (!toolbarIsShowing || inOverlayMode) ? 0 : BadgeWithBackdrop.backdropAlpha
        }
        
    }

    func animateToOverlayState(overlayMode overlay: Bool, didCancel cancel: Bool = false) {
        prepareOverlayAnimation()
        layoutIfNeeded()

        inOverlayMode = overlay

        if !overlay {
            removeLocationTextField()
        }

        UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.0, options: [], animations: {
            self.transitionToOverlay(cancel)
            self.setNeedsUpdateConstraints()
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

extension URLBarView: TabToolbarProtocol {
    func privateModeBadge(visible: Bool) {
        if UIDevice.current.userInterfaceIdiom != .pad {
            privateModeBadge.show(visible)
        }
    }

    func appMenuBadge(setVisible: Bool) {
        // Warning badges should take priority over the standard badge
        guard warningMenuBadge.badge.isHidden else {
            return
        }

        appMenuBadge.show(setVisible)
    }

    func warningMenuBadge(setVisible: Bool) {
        // Disable other menu badges before showing the warning.
        if !appMenuBadge.badge.isHidden { appMenuBadge.show(false) }
        warningMenuBadge.show(setVisible)
    }

    func updateBackStatus(_ canGoBack: Bool) {
        backButton.isEnabled = canGoBack
    }

    func updateForwardStatus(_ canGoForward: Bool) {
        forwardButton.isEnabled = canGoForward
    }

    func updateTabCount(_ count: Int, animated: Bool = true) {
        tabsButton.updateTabCount(count, animated: animated)
    }

    func updatePageStatus(_ isWebPage: Bool) {
        shareButton.isEnabled = isWebPage
    }

    var access: [Any]? {
        get {
            if inOverlayMode {
                guard let locationTextField = locationTextField else { return nil }
                return [locationTextField, cancelButton]
            } else {
                if toolbarIsShowing {
                    return [backButton, forwardButton, neevaMenuButton, locationContainer, shareButton, spacesMenuButton, tabsButton, progressBar]
                } else {
                    return [neevaMenuButton, locationContainer, progressBar]
                }
            }
        }
        set {
            super.accessibilityElements = newValue
        }
    }
}

extension URLBarView: TabLocationViewDelegate {

    func tabLocationViewDidLongPressReaderMode(_ tabLocationView: TabLocationView) -> Bool {
        return delegate?.urlBarDidLongPressReaderMode(self) ?? false
    }

    func tabLocationViewReloadMenu(_ tabLocationView: TabLocationView) -> UIMenu? {
        delegate?.urlBarReloadMenu(self, from: tabLocationView.reloadButton)
    }

    func tabLocationViewDidTapLocation(_ tabLocationView: TabLocationView) {
        guard let (locationText, isSearchQuery) = delegate?.urlBarDisplayTextForURL(locationView.url as URL?) else { return }

        var overlayText = locationText
        // Make sure to use the result from urlBarDisplayTextForURL as it is responsible for extracting out search terms when on a search page
        if let text = locationText, let url = URL(string: text), let host = url.host, AppConstants.MOZ_PUNYCODE {
            overlayText = url.absoluteString.replacingOccurrences(of: host, with: host.asciiHostToUTF8())
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

extension URLBarView: AutocompleteTextFieldDelegate {
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
extension URLBarView {
    @objc dynamic var cancelTintColor: UIColor? {
        get { return cancelButton.tintColor }
        set { return cancelButton.tintColor = newValue }
    }
}

extension URLBarView: Themeable {
    func applyTheme() {
        locationView.applyTheme()
        locationTextField?.applyTheme()

        actionButtons.forEach { $0.applyTheme() }
        tabsButton.applyTheme()

        cancelTintColor = UIColor.theme.browser.tint
        backgroundColor = UIColor.theme.browser.background
        line.backgroundColor = UIColor.theme.browser.urlBarDivider

        locationView.backgroundColor = inOverlayMode ? UIColor.theme.textField.backgroundInOverlay : UIColor.theme.textField.background
        locationContainer.backgroundColor = UIColor.clear

        privateModeBadge.badge.tintBackground(color: UIColor.theme.browser.background)
        appMenuBadge.badge.tintBackground(color: UIColor.theme.browser.background)
        warningMenuBadge.badge.tintBackground(color: UIColor.theme.browser.background)
    }
}

extension URLBarView: PrivateModeUI {
    func applyUIMode(isPrivate: Bool) {
        if UIDevice.current.userInterfaceIdiom != .pad {
            privateModeBadge.show(isPrivate)
        }
        
        progressBar.setGradientColors(startColor: UIColor.theme.loadingBar.start(isPrivate), endColor: UIColor.theme.loadingBar.end(isPrivate))
        ToolbarTextField.applyUIMode(isPrivate: isPrivate)

        if isPrivate {
            neevaMenuButton.setImage(neevaMenuIcon?.withRenderingMode(.alwaysTemplate), for: .normal)
        } else {
            neevaMenuButton.setImage(neevaMenuIcon, for: .normal)
        }
        neevaMenuButton.tintColor = UIColor.theme.urlbar.neevaMenuTint(isPrivate)

        applyTheme()
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
        layer.cornerRadius = URLBarViewUX.TextFieldCornerRadius
        layer.masksToBounds = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ToolbarTextField: AutocompleteTextField {

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

extension ToolbarTextField: Themeable {
    func applyTheme() {
        backgroundColor = UIColor.theme.textField.backgroundInOverlay
        textColor = UIColor.theme.textField.textAndTint
        clearButtonTintColor = textColor
        tintColor = AutocompleteTextField.textSelectionColor.textFieldMode
    }

    // ToolbarTextField is created on-demand, so the textSelectionColor is a static prop for use when created
    static func applyUIMode(isPrivate: Bool) {
       textSelectionColor = UIColor.theme.urlbar.textSelectionHighlight(isPrivate)
    }
}
