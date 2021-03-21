/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Shared
import SnapKit
import XCGLogger

private let log = Logger.browserLogger

protocol TabLocationViewDelegate {
    func tabLocationViewDidTapLocation(_ tabLocationView: TabLocationView)
    func tabLocationViewDidLongPressLocation(_ tabLocationView: TabLocationView)
    func tabLocationViewDidTapReload(_ tabLocationView: TabLocationView)
    func tabLocationViewDidTapShield(_ tabLocationView: TabLocationView)
    func tabLocationViewDidBeginDragInteraction(_ tabLocationView: TabLocationView)

    func tabLocationViewReloadMenu(_ tabLocationView: TabLocationView) -> UIMenu?
    func tabLocationViewLocationAccessibilityActions(_ tabLocationView: TabLocationView) -> [UIAccessibilityCustomAction]?
}

private struct TabLocationViewUX {
    static let HostFontColor = UIColor.black
    static let BaseURLFontColor = UIColor.Photon.Grey50
    static let Spacing: CGFloat = 8
    static let StatusIconSize: CGFloat = 18
    static let TPIconSize: CGFloat = 44
    static let ReloadButtonWidth: CGFloat = 44
    static let ButtonSize: CGFloat = 44
    static let URLBarPadding = 4
}

class TabLocationView: UIView {
    var delegate: TabLocationViewDelegate?
    var longPressRecognizer: UILongPressGestureRecognizer!
    var tapRecognizer: UITapGestureRecognizer!
    var contentView: UIStackView!

    fileprivate let menuBadge = BadgeWithBackdrop(imageName: "menuBadge", backdropCircleSize: 32)

    @objc dynamic var baseURLFontColor: UIColor = TabLocationViewUX.BaseURLFontColor {
        didSet { updateTextWithURL() }
    }

    func showLockIcon(forSecureContent isSecure: Bool) {
        if url?.absoluteString == "about:blank" {
            // Matching the desktop behaviour, we don't mark these pages as secure.
            lockImageView.isHidden = true
            return
        }
        lockImageView.isHidden = !isSecure
    }

    var url: URL? {
        didSet {
            updateTextWithURL()
            let showSearchIcon = neevaSearchEngine.queryForSearchURL(url) == nil
            searchImageViews.0.isHidden = showSearchIcon
            searchImageViews.1.isHidden = showSearchIcon

            trackingProtectionButton.isHidden = !["https", "http"].contains(url?.scheme ?? "")
            setNeedsUpdateConstraints()
        }
    }

    lazy var placeholder: NSAttributedString = {
        return NSAttributedString(string: .TabLocationURLPlaceholder, attributes: [NSAttributedString.Key.foregroundColor: UIColor.Photon.Grey50])
    }()

    lazy var urlTextField: UITextField = {
        let urlTextField = DisplayTextField()

        // Prevent the field from compressing the toolbar buttons on the 4S in landscape.
        urlTextField.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 250), for: .horizontal)
        urlTextField.attributedPlaceholder = self.placeholder
        urlTextField.accessibilityIdentifier = "url"
        urlTextField.accessibilityActionsSource = self
        urlTextField.font = UIConstants.DefaultChromeFont
        urlTextField.backgroundColor = .clear
        urlTextField.accessibilityLabel = "Address Bar"
        urlTextField.font = UIFont.preferredFont(forTextStyle: .body)
        urlTextField.adjustsFontForContentSizeCategory = true
        urlTextField.textAlignment = .center

        // Remove the default drop interaction from the URL text field so that our
        // custom drop interaction on the BVC can accept dropped URLs.
        if let dropInteraction = urlTextField.textDropInteraction {
            urlTextField.removeInteraction(dropInteraction)
        }

        return urlTextField
    }()

    fileprivate lazy var lockImageView: UIImageView = {
        let lockImageView = UIImageView(image: UIImage.templateImageNamed("lock_verified"))
        lockImageView.isAccessibilityElement = true
        lockImageView.contentMode = .center
        lockImageView.accessibilityLabel = .TabLocationLockIconAccessibilityLabel
        return lockImageView
    }()
    
    fileprivate lazy var searchImageViews: (UIView, UIImageView) = {
          let searchImageView = UIImageView(image: UIImage.templateImageNamed("search"))
          searchImageView.isAccessibilityElement = false
          searchImageView.contentMode = .scaleAspectFit
          let space10px = UIView()
          space10px.snp.makeConstraints { make in
              make.width.equalTo(10)
          }
          return (space10px, searchImageView)
    }()

    class TrackingProtectionButton: UIButton {
        var separatorLine: UIView?
    }

    lazy var trackingProtectionButton: TrackingProtectionButton = {
        let trackingProtectionButton = TrackingProtectionButton()
        trackingProtectionButton.setImage(UIImage.templateImageNamed("tracking-protection"), for: .normal)
        trackingProtectionButton.addTarget(self, action: #selector(didPressTPShieldButton(_:)), for: .touchUpInside)
        trackingProtectionButton.tintColor = UIColor.Photon.Grey50
        trackingProtectionButton.imageView?.contentMode = .scaleAspectFill
        trackingProtectionButton.accessibilityIdentifier = "TabLocationView.trackingProtectionButton"
        return trackingProtectionButton
    }()

    lazy var reloadButton: StatefulButton = {
        let reloadButton = StatefulButton(frame: .zero, state: .disabled)
        reloadButton.addTarget(self, action: #selector(tapReloadButton), for: .touchUpInside)
        reloadButton.setDynamicMenu { self.delegate?.tabLocationViewReloadMenu(self) }
        reloadButton.tintColor = UIColor.Photon.Grey50
        reloadButton.imageView?.contentMode = .scaleAspectFit
        reloadButton.accessibilityLabel = .TabLocationReloadAccessibilityLabel
        reloadButton.accessibilityIdentifier = "TabLocationView.reloadButton"
        reloadButton.isAccessibilityElement = true
        return reloadButton
    }()
    
    private func makeSeparator() -> UIView {
        let line = UIView()
        line.layer.cornerRadius = 2
        return line
    }

    // A vertical separator next to the page options button.
    lazy var separatorLineForPageOptions: UIView = makeSeparator()

    lazy var separatorLineForTP: UIView = makeSeparator()

    override init(frame: CGRect) {
        super.init(frame: frame)

        register(self, forTabEvents: .didGainFocus, .didToggleDesktopMode, .didChangeContentBlocking)

        longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressLocation))
        longPressRecognizer.delegate = self

        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapLocation))
        tapRecognizer.delegate = self

        addGestureRecognizer(longPressRecognizer)
        addGestureRecognizer(tapRecognizer)

        let space10px = UIView()
        space10px.snp.makeConstraints { make in
            make.width.equalTo(10)
        }

        // Link these so they hide/show in-sync.
        trackingProtectionButton.separatorLine = separatorLineForTP

        let subviews = [ space10px, lockImageView, urlTextField, reloadButton, trackingProtectionButton]
        
        contentView = UIStackView(arrangedSubviews: subviews)
        contentView.distribution = .fill
        contentView.alignment = .center
        addSubview(contentView)

        contentView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }

        lockImageView.snp.makeConstraints { make in
            make.width.equalTo(28)
        }
        trackingProtectionButton.snp.makeConstraints { make in
            make.width.equalTo(TabLocationViewUX.TPIconSize)
            make.height.equalTo(TabLocationViewUX.ButtonSize)
        }
        reloadButton.snp.makeConstraints { make in
            make.width.equalTo(TabLocationViewUX.ReloadButtonWidth)
            make.height.equalTo(TabLocationViewUX.ButtonSize)
        }

        // Setup UIDragInteraction to handle dragging the location
        // bar for dropping its URL into other apps.
        let dragInteraction = UIDragInteraction(delegate: self)
        dragInteraction.allowsSimultaneousRecognitionDuringLift = true
        self.addInteraction(dragInteraction)

        menuBadge.add(toParent: contentView)
        menuBadge.show(false)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var _accessibilityElements = [urlTextField, reloadButton, trackingProtectionButton]

    override var accessibilityElements: [Any]? {
        get {
            return _accessibilityElements.filter { !$0.isHidden }
        }
        set {
            super.accessibilityElements = newValue
        }
    }

    func overrideAccessibility(enabled: Bool) {
        _accessibilityElements.forEach {
            $0.isAccessibilityElement = enabled
        }
    }

    @objc func tapReloadButton() {
        delegate?.tabLocationViewDidTapReload(self)
    }

    @objc func longPressLocation(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .began {
            delegate?.tabLocationViewDidLongPressLocation(self)
        }
    }

    @objc func tapLocation(_ recognizer: UITapGestureRecognizer) {
        delegate?.tabLocationViewDidTapLocation(self)
    }

    @objc func didPressTPShieldButton(_ button: UIButton) {
        delegate?.tabLocationViewDidTapShield(self)
    }

    fileprivate func updateTextWithURL() {
        if let scheme = url?.scheme, let range = url?.absoluteString.range(of: "\(scheme)://") {
            // remove https:// (the scheme) from the url when displaying
                        urlTextField.text = url?.absoluteString.replacingCharacters(in: range, with: "")
        } else {
            urlTextField.text = url?.absoluteString
        }
        // NOTE: Punycode support was removed
        if let query = neevaSearchEngine.queryForSearchURL(url) {
            urlTextField.text = query
        }
    }
}

extension TabLocationView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // When long pressing a button make sure the textfield's long press gesture is not triggered
        return !(otherGestureRecognizer.view is UIButton)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // If the longPressRecognizer is active, fail the tap recognizer to avoid conflicts.
        return gestureRecognizer == longPressRecognizer && otherGestureRecognizer == tapRecognizer
    }
}

@available(iOS 11.0, *)
extension TabLocationView: UIDragInteractionDelegate {
    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
        // Ensure we actually have a URL in the location bar and that the URL is not local.
        guard let url = self.url, !InternalURL.isValid(url: url), let itemProvider = NSItemProvider(contentsOf: url) else {
            return []
        }

        TelemetryWrapper.recordEvent(category: .action, method: .drag, object: .locationBar)

        let dragItem = UIDragItem(itemProvider: itemProvider)
        return [dragItem]
    }

    func dragInteraction(_ interaction: UIDragInteraction, sessionWillBegin session: UIDragSession) {
        delegate?.tabLocationViewDidBeginDragInteraction(self)
    }
}

extension TabLocationView: AccessibilityActionsSource {
    func accessibilityCustomActionsForView(_ view: UIView) -> [UIAccessibilityCustomAction]? {
        if view === urlTextField {
            return delegate?.tabLocationViewLocationAccessibilityActions(self)
        }
        return nil
    }
}

extension TabLocationView: Themeable {
    func applyTheme() {
        backgroundColor = UIColor.theme.textField.background
        urlTextField.textColor = UIColor.theme.textField.textAndTint

        separatorLineForPageOptions.backgroundColor = UIColor.Photon.Grey40
        separatorLineForTP.backgroundColor = separatorLineForPageOptions.backgroundColor

        let color = ThemeManager.instance.currentName == .dark ? UIColor(white: 0.3, alpha: 0.6): UIColor.theme.textField.background
        menuBadge.badge.tintBackground(color: color)
    }
}

extension TabLocationView: TabEventHandler {
    func tabDidChangeContentBlocking(_ tab: Tab) {
        updateBlockerStatus(forTab: tab)
    }

    private func updateBlockerStatus(forTab tab: Tab) {
        assertIsMainThread("UI changes must be on the main thread")
        guard let blocker = tab.contentBlocker else { return }
        trackingProtectionButton.alpha = 1.0
        switch blocker.status {
        case .blocking:
            let blockImageName = ThemeManager.instance.currentName == .dark ? "tracking-protection-active-block-dark" : "tracking-protection-active-block"
            trackingProtectionButton.setImage(UIImage(imageLiteralResourceName: blockImageName), for: .normal)
        case .noBlockedURLs:
            trackingProtectionButton.setImage(UIImage.templateImageNamed("tracking-protection"), for: .normal)
            trackingProtectionButton.alpha = 0.5
        case .safelisted:
            trackingProtectionButton.setImage(UIImage.templateImageNamed("tracking-protection-off"), for: .normal)
        case .disabled:
            break
        }
    }

    func tabDidGainFocus(_ tab: Tab) {
        updateBlockerStatus(forTab: tab)
        menuBadge.show(tab.changedUserAgent)
    }

    func tabDidToggleDesktopMode(_ tab: Tab) {
        menuBadge.show(tab.changedUserAgent)
    }
}

enum ReloadButtonState: String {
    case reload = "Reload"
    case stop = "Stop"
    case disabled = "Disabled"
}

class StatefulButton: UIButton {
    convenience init(frame: CGRect, state: ReloadButtonState) {
        self.init(frame: frame)
        reloadButtonState = state
    }

    required override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var _reloadButtonState = ReloadButtonState.disabled
    
    var reloadButtonState: ReloadButtonState {
        get {
            return _reloadButtonState
        }
        set (newReloadButtonState) {
            _reloadButtonState = newReloadButtonState
            
            let configuration = UIImage.SymbolConfiguration(weight: .semibold)
            switch _reloadButtonState {
            case .reload:
                self.isHidden = false
                setImage(UIImage(systemName: "arrow.clockwise", withConfiguration: configuration), for: .normal)
            case .stop:
                self.isHidden = false
                setImage(UIImage(systemName: "xmark", withConfiguration: configuration), for: .normal)
            case .disabled:
                self.isHidden = true
            }
        }
    }
}

class ReaderModeButton: UIButton {
    var selectedTintColor: UIColor?
    var unselectedTintColor: UIColor?
    override init(frame: CGRect) {
        super.init(frame: frame)
        adjustsImageWhenHighlighted = false
        setImage(UIImage.templateImageNamed("reader"), for: .normal)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isSelected: Bool {
        didSet {
            self.tintColor = (isHighlighted || isSelected) ? selectedTintColor : unselectedTintColor
        }
    }

    override open var isHighlighted: Bool {
        didSet {
            self.tintColor = (isHighlighted || isSelected) ? selectedTintColor : unselectedTintColor
        }
    }

    override var tintColor: UIColor! {
        didSet {
            self.imageView?.tintColor = self.tintColor
        }
    }

    var _readerModeState = ReaderModeState.unavailable

    var readerModeState: ReaderModeState {
        get {
            return _readerModeState
        }
        set (newReaderModeState) {
            _readerModeState = newReaderModeState
            switch _readerModeState {
            case .available:
                self.isEnabled = true
                self.isSelected = false
            case .unavailable:
                self.isEnabled = false
                self.isSelected = false
            case .active:
                self.isEnabled = true
                self.isSelected = true
            }
        }
    }
}

private class DisplayTextField: UITextField {
    weak var accessibilityActionsSource: AccessibilityActionsSource?

    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            return accessibilityActionsSource?.accessibilityCustomActionsForView(self)
        }
        set {
            super.accessibilityCustomActions = newValue
        }
    }

    fileprivate override var canBecomeFirstResponder: Bool {
        return false
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: TabLocationViewUX.Spacing, dy: 0)
    }
}
