/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Shared
import Storage
import XCGLogger
import WebKit

protocol HistoryPanelDelegate: AnyObject {
    func libraryPanelDidRequestToOpenInNewTab(_ url: URL, _ savedTab: SavedTab?, isPrivate: Bool)
    func libraryPanel(didSelectURL url: URL, visitType: VisitType)
    func libraryPanel(didSelectURLString url: String, visitType: VisitType)
}



private enum HistoryPanelUX {
    static let WelcomeScreenItemWidth = 170
    static let IconSize = 23
    static let IconBorderColor = UIColor.Photon.Grey30
    static let IconBorderWidth: CGFloat = 0.5
    static let actionIconColor = UIColor.Photon.Grey40 // Works for light and dark theme.
}

private class FetchInProgressError: MaybeErrorType {
    internal var description: String {
        return "Fetch is already in-progress"
    }
}

@objcMembers
class HistoryPanel: SiteTableViewController {
    enum Section: Int {
        // Showing showing recently closed, and clearing recent history are action rows of this type.
        case additionalHistoryActions
        case today
        case yesterday
        case lastWeek
        case lastMonth

        static let count = 5

        var title: String? {
            switch self {
            case .today:
                return Strings.TableDateSectionTitleToday
            case .yesterday:
                return Strings.TableDateSectionTitleYesterday
            case .lastWeek:
                return Strings.TableDateSectionTitleLastWeek
            case .lastMonth:
                return Strings.TableDateSectionTitleLastMonth
            default:
                return nil
            }
        }
    }

    enum AdditionalHistoryActionRow: Int {
        case clearRecent
        case showRecentlyClosedTabs

        // Use to enable/disable the additional history action rows.
        static func setStyle(enabled: Bool, forCell cell: UITableViewCell) {
            if enabled {
                cell.textLabel?.alpha = 1.0
                cell.imageView?.alpha = 1.0
                cell.selectionStyle = .default
                cell.isUserInteractionEnabled = true
            } else {
                cell.textLabel?.alpha = 0.5
                cell.imageView?.alpha = 0.5
                cell.selectionStyle = .none
                cell.isUserInteractionEnabled = false
            }
        }
    }

    let QueryLimitPerFetch = 100

    var delegate: HistoryPanelDelegate?

    var tabManager: TabManager!

    var groupedSites = DateGroupedTableData<Site>()

    var refreshControl: UIRefreshControl?

    var currentFetchOffset = 0
    var isFetchInProgress = false

    var clearHistoryCell: UITableViewCell?

    var hasRecentlyClosed: Bool {
        return BrowserViewController.foregroundBVC().tabManager.recentlyClosedTabs.count > 0
    }

    lazy var emptyStateOverlayView: UIView = createEmptyStateOverlayView()

    // MARK: - Lifecycle
    override init(profile: Profile) {
        super.init(profile: profile)

        [ Notification.Name.PrivateDataClearedHistory,
          Notification.Name.DynamicFontChanged,
          Notification.Name.DatabaseWasReopened ].forEach {
            NotificationCenter.default.addObserver(self, selector: #selector(onNotificationReceived), name: $0, object: nil)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.accessibilityIdentifier = "History List"
        tableView.prefetchDataSource = self

        tabManager = BrowserViewController.foregroundBVC().tabManager

        updateEmptyPanelState()

        navigationItem.title = .LibraryPanelHistoryAccessibilityLabel
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true, completion: nil)
        })
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Done"

        self.accessibilityLabel = "History Panel"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        removeRefreshControl()
    }

    // MARK: - Refreshing TableView

    func addRefreshControl() {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(onRefreshPulled), for: .valueChanged)
        refreshControl = control
        tableView.refreshControl = control
    }

    func removeRefreshControl() {
        tableView.refreshControl = nil
        refreshControl = nil
    }

    func endRefreshing() {
        // Always end refreshing, even if we failed!
        refreshControl?.endRefreshing()

    }

    // MARK: - Loading data

    override func reloadData() {
        // Can be called while app backgrounded and the db closed, don't try to reload the data source in this case
        if profile.isShutdown { return }
        guard !isFetchInProgress else { return }
        groupedSites = DateGroupedTableData<Site>()

        currentFetchOffset = 0
        fetchData().uponQueue(.main) { result in
            if let sites = result.successValue {
                for site in sites {
                    if let site = site, let latestVisit = site.latestVisit {
                        self.groupedSites.add(site, timestamp: TimeInterval.fromMicrosecondTimestamp(latestVisit.date))
                    }
                }

                self.tableView.reloadData()
                self.updateEmptyPanelState()

                if let cell = self.clearHistoryCell {
                    AdditionalHistoryActionRow.setStyle(enabled: !self.groupedSites.isEmpty, forCell: cell)
                }

            }
        }
    }

    func fetchData() -> Deferred<Maybe<Cursor<Site>>> {
        guard !isFetchInProgress else {
            return deferMaybe(FetchInProgressError())
        }

        isFetchInProgress = true

        return profile.history.getSitesByLastVisit(limit: QueryLimitPerFetch, offset: currentFetchOffset) >>== { result in
            // Force 100ms delay between resolution of the last batch of results
            // and the next time `fetchData()` can be called.
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                self.currentFetchOffset += self.QueryLimitPerFetch
                self.isFetchInProgress = false
            }

            return deferMaybe(result)
        }
    }

    // MARK: - Actions

    func removeHistoryForURLAtIndexPath(indexPath: IndexPath) {
        guard let site = siteForIndexPath(indexPath) else {
            return
        }

        profile.history.removeHistoryForURL(site.url).uponQueue(.main) { result in
            guard site == self.siteForIndexPath(indexPath) else {
                self.reloadData()
                return
            }
            self.tableView.beginUpdates()
            self.groupedSites.remove(site)
            self.tableView.deleteRows(at: [indexPath], with: .right)
            self.tableView.endUpdates()
            self.updateEmptyPanelState()

            if let cell = self.clearHistoryCell {
                AdditionalHistoryActionRow.setStyle(enabled: !self.groupedSites.isEmpty, forCell: cell)
            }
        }
    }

    func pinToTopSites(_ site: Site) {
        profile.history.addPinnedTopSite(site).uponQueue(.main) { result in
            if result.isSuccess {
                let toastView = ToastViewManager.shared.makeToast(text: Strings.AppMenuAddPinToTopSitesConfirmMessage)
                ToastViewManager.shared.enqueue(toast: toastView)
            }
        }
    }

    func navigateToRecentlyClosed() {
        guard hasRecentlyClosed else {
            return
        }

        let nextController = RecentlyClosedTabsPanel(profile: profile)
        nextController.title = Strings.RecentlyClosedTabsButtonTitle
        nextController.delegate = delegate
        refreshControl?.endRefreshing()
        navigationController?.pushViewController(nextController, animated: true)
    }

    func showClearRecentHistory() {
        func remove(hoursAgo: Int) {
            if let date = Calendar.current.date(byAdding: .hour, value: -hoursAgo, to: Date()) {
                let types = WKWebsiteDataStore.allWebsiteDataTypes()
                WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: date, completionHandler: {})

                self.profile.history.removeHistoryFromDate(date).uponQueue(.main) { _ in
                    self.reloadData()
                }
            }
        }

        let alert = UIAlertController(title: Strings.ClearHistoryMenuTitle, message: nil, preferredStyle: .actionSheet)

        // This will run on the iPad-only, and sets the alert to be centered with no arrow.
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }

        [(Strings.ClearHistoryMenuOptionTheLastHour, 1),
         (Strings.ClearHistoryMenuOptionToday, 24),
         (Strings.ClearHistoryMenuOptionTodayAndYesterday, 48)].forEach {
            (name, time) in
            let action = UIAlertAction(title: name, style: .destructive) { _ in
                remove(hoursAgo: time)
            }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: Strings.ClearHistoryMenuOptionEverything, style: .destructive, handler: { _ in
            let types = WKWebsiteDataStore.allWebsiteDataTypes()
            WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast, completionHandler: {})
            self.profile.history.clearHistory().uponQueue(.main) { _ in
                self.reloadData()
            }

            BrowserViewController.foregroundBVC().tabManager.recentlyClosedTabs.removeAll()
        }))
        let cancelAction = UIAlertAction(title: Strings.CancelString, style: .cancel)
        cancelAction.accessibilityLabel = "Cancel"
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }

    // MARK: - Cell configuration

    func siteForIndexPath(_ indexPath: IndexPath) -> Site? {
        // First section is reserved for recently closed.
        guard indexPath.section > Section.additionalHistoryActions.rawValue else {
            return nil
        }

        let sitesInSection = groupedSites.itemsForSection(indexPath.section - 1)
        return sitesInSection[safe: indexPath.row]
    }

    func configureClearHistory(_ cell: UITableViewCell, for indexPath: IndexPath) -> UITableViewCell {
        clearHistoryCell = cell
        cell.textLabel?.text = Strings.HistoryPanelClearHistoryButtonTitle
        cell.detailTextLabel?.text = ""
        cell.imageView?.image = UIImage.templateImageNamed("forget")
        cell.imageView?.tintColor = HistoryPanelUX.actionIconColor
        cell.accessibilityIdentifier = "HistoryPanel.clearHistory"

        var isEmpty = true
        for i in Section.today.rawValue..<tableView.numberOfSections {
            if tableView.numberOfRows(inSection: i) > 0 {
                isEmpty = false
            }
        }
        AdditionalHistoryActionRow.setStyle(enabled: !isEmpty, forCell: cell)

        return cell
    }

    func configureRecentlyClosed(_ cell: UITableViewCell, for indexPath: IndexPath) -> UITableViewCell {
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.text = Strings.RecentlyClosedTabsButtonTitle
        cell.detailTextLabel?.text = ""
        cell.imageView?.image = UIImage.templateImageNamed("recently_closed")
        cell.imageView?.tintColor = HistoryPanelUX.actionIconColor
        AdditionalHistoryActionRow.setStyle(enabled: hasRecentlyClosed, forCell: cell)
        cell.accessibilityIdentifier = "HistoryPanel.recentlyClosedCell"
        return cell
    }

    func configureSite(_ cell: UITableViewCell, for indexPath: IndexPath) -> UITableViewCell {
        if let site = siteForIndexPath(indexPath), let cell = cell as? TwoLineTableViewCell {
            cell.setLines(site.title, detailText: site.url)

            cell.imageView?.layer.borderColor = HistoryPanelUX.IconBorderColor.cgColor
            cell.imageView?.layer.borderWidth = HistoryPanelUX.IconBorderWidth
            cell.imageView?.contentMode = .center
            cell.imageView?.setImageAndBackground(forIcon: site.icon, website: site.tileURL) { [weak cell] in
                cell?.imageView?.image = cell?.imageView?.image?.createScaled(CGSize(width: HistoryPanelUX.IconSize, height: HistoryPanelUX.IconSize))
            }
        }
        return cell
    }

    // MARK: - Selector callbacks

    func onNotificationReceived(_ notification: Notification) {
        switch notification.name {
        case .PrivateDataClearedHistory:
            reloadData()

            break
        case .DynamicFontChanged:
            reloadData()

            if emptyStateOverlayView.superview != nil {
                emptyStateOverlayView.removeFromSuperview()
            }
            emptyStateOverlayView = createEmptyStateOverlayView()
            break
        case .DatabaseWasReopened:
            if let dbName = notification.object as? String, dbName == "browser.db" {
                reloadData()
            }
        default:
            // no need to do anything at all
            print("Error: Received unexpected notification \(notification.name)")
            break
        }
    }

    func onRefreshPulled() {
        refreshControl?.beginRefreshing()
    }

    // MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // First section is for recently closed and always has 1 row.
        guard section > Section.additionalHistoryActions.rawValue else {
            return 2
        }

        return groupedSites.numberOfItemsForSection(section - 1)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // First section is for recently closed and has no title.
        guard section > Section.additionalHistoryActions.rawValue else {
            return nil
        }

        // Ensure there are rows in this section.
        guard groupedSites.numberOfItemsForSection(section - 1) > 0 else {
            return nil
        }

        return Section(rawValue: section)?.title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.accessoryType = .none

        // First section is reserved for recently closed.
        guard indexPath.section > Section.additionalHistoryActions.rawValue else {
            cell.imageView?.layer.borderWidth = 0

            guard let row = AdditionalHistoryActionRow(rawValue: indexPath.row) else {
                assertionFailure("Bad row number")
                return cell
            }

            switch row {
            case .clearRecent:
                return configureClearHistory(cell, for: indexPath)
            case .showRecentlyClosedTabs:
                return configureRecentlyClosed(cell, for: indexPath)
            }
        }

        return configureSite(cell, for: indexPath)
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // First section is reserved for recently closed.
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        guard indexPath.section > Section.additionalHistoryActions.rawValue else {
            switch indexPath.row {
            case 0:
                showClearRecentHistory()
            default:
                navigateToRecentlyClosed()
            }
            return
        }

        if let site = siteForIndexPath(indexPath), let url = URL(string: site.url) {
            if let delegate = delegate {
                delegate.libraryPanel(didSelectURL: url, visitType: VisitType.typed)
            }
            return
        }
        print("Error: No site or no URL when selecting row.")
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let site = siteForIndexPath(indexPath) else { return nil }

        return createHistoryLinkMenu(for: site,
                                            pinToTopSites: { self.pinToTopSites(site) },
                                            removeHistoryForURLAtIndexPath: { self.removeHistoryForURLAtIndexPath(indexPath: indexPath) }) { tab, isPrivate in
            let toastLabelText: String = isPrivate ? Strings.ContextMenuButtonToastNewIncognitoTabOpenedLabelText : Strings.ContextMenuButtonToastNewTabOpenedLabelText
            let toastView = ToastViewManager.shared.makeToast(text: toastLabelText, buttonText: Strings.ContextMenuButtonToastNewTabOpenedButtonText, buttonAction: {
                self.tabManager.selectTab(tab)
            })

            ToastViewManager.shared.enqueue(toast: toastView)
        }
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        // Intentionally blank. Required to use UITableViewRowActions
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if indexPath.section == Section.additionalHistoryActions.rawValue {
            return []
        }
        let title: String = .HistoryPanelDelete

        let delete = UITableViewRowAction(style: .default, title: title, handler: { (action, indexPath) in
            self.removeHistoryForURLAtIndexPath(indexPath: indexPath)
        })
        return [delete]
    }

    // MARK: - Empty State
    func updateEmptyPanelState() {
        if groupedSites.isEmpty {
            if emptyStateOverlayView.superview == nil {
                tableView.tableFooterView = emptyStateOverlayView
            }
        } else {
            tableView.alwaysBounceVertical = true
            tableView.tableFooterView = nil
        }
    }

    func createEmptyStateOverlayView() -> UIView {
        let overlayView = UIView()

        // overlayView becomes the footer view, and for unknown reason, setting the bgcolor is ignored.
        // Create an explicit view for setting the color.
        let bgColor = UIView()
        bgColor.backgroundColor = .systemBackground
        overlayView.addSubview(bgColor)
        bgColor.snp.makeConstraints { make in
            // Height behaves oddly: equalToSuperview fails in this case, as does setting top.equalToSuperview(), simply setting this to ample height works.
            make.height.equalTo(UIScreen.main.bounds.height)
            make.width.equalToSuperview()
        }

        let welcomeLabel = UILabel()
        overlayView.addSubview(welcomeLabel)
        welcomeLabel.text = Strings.HistoryPanelEmptyStateTitle
        welcomeLabel.textAlignment = .center
        welcomeLabel.font = DynamicFontHelper.defaultHelper.DeviceFontLight
        welcomeLabel.textColor = UIColor.HomePanel.welcomeScreenText
        welcomeLabel.numberOfLines = 0
        welcomeLabel.adjustsFontSizeToFitWidth = true

        welcomeLabel.snp.makeConstraints { make in
            make.centerX.equalTo(overlayView)
            // Sets proper top constraint for iPhone 6 in portait and for iPad.
            make.centerY.equalTo(overlayView).offset(-180).priority(100)
            // Sets proper top constraint for iPhone 4, 5 in portrait.
            make.top.greaterThanOrEqualTo(overlayView).offset(50)
            make.width.equalTo(HistoryPanelUX.WelcomeScreenItemWidth)
        }
        return overlayView
    }

    func createHistoryLinkMenu(for site: Site, pinToTopSites: @escaping () -> Void,
                              removeHistoryForURLAtIndexPath: @escaping () -> Void, openedTab: @escaping (Tab?, Bool) -> Void) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let currentTab = self.tabManager.selectedTab

            guard let url = URL(string: site.url) else {
                return nil
            }

            let newTabAction = UIAction(
                title: "Open in New tab",
                image: UIImage(systemName: "plus.square")) { _ in
                let tab = self.tabManager.addTab(URLRequest(url: url), afterTab: currentTab, isPrivate: false)
                openedTab(tab, false)
            }

            let newIncognitoTabAction = UIAction(
                title: "Open in New Incognito Tab",
                image: UIImage(named: "incognito")?.withRenderingMode(.alwaysTemplate)) { _ in
                let tab = self.tabManager.addTab(URLRequest(url: url), afterTab: currentTab, isPrivate: true)
                openedTab(tab, true)
            }

            let pinTopSite = UIAction(
                title: Strings.PinTopsiteActionTitle,
                image: UIImage(named: "action_pin")?.withRenderingMode(.alwaysTemplate)) { _ in
                pinToTopSites()
            }

            let removeAction = UIAction(
                title: Strings.DeleteFromHistoryContextMenuTitle,
                image: UIImage(named: "action_delete")?.withRenderingMode(.alwaysTemplate), attributes: .destructive) { _ in
                removeHistoryForURLAtIndexPath()
            }
            removeAction.accessibilityLabel = Strings.DeleteFromHistoryContextMenuTitle

            return UIMenu(children: FeatureFlag[.pinToTopSites] ? [newTabAction, newIncognitoTabAction, pinTopSite, removeAction] : [newTabAction, newIncognitoTabAction, removeAction])
        }
    }
}

extension HistoryPanel: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        guard !isFetchInProgress, indexPaths.contains(where: shouldLoadRow) else {
            return
        }

        fetchData().uponQueue(.main) { result in
            if let sites = result.successValue {
                let indexPaths: [IndexPath] = sites.compactMap({ site in
                    guard let site = site, let latestVisit = site.latestVisit else {
                        return nil
                    }

                    let indexPath = self.groupedSites.add(site, timestamp: TimeInterval.fromMicrosecondTimestamp(latestVisit.date))
                    return IndexPath(row: indexPath.row, section: indexPath.section + 1)
                })

                self.tableView.insertRows(at: indexPaths, with: .automatic)
            }
        }
    }

    func shouldLoadRow(for indexPath: IndexPath) -> Bool {
        guard indexPath.section > Section.additionalHistoryActions.rawValue else {
            return false
        }

        return indexPath.row >= groupedSites.numberOfItemsForSection(indexPath.section - 1) - 1
    }
}
