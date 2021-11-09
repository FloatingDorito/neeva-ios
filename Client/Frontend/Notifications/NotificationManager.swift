// Copyright Neeva. All rights reserved.

import Combine
import Defaults
import Foundation
import Shared
import SwiftUI

private let logger = Logger.browser

class NotificationManager: ObservableObject {
    static let promoIdKey = "PromoId"
    static let shared = NotificationManager()

    public struct notificationKey {
        public static let deeplinkURL = "deeplinkURL"
        public static let campaignID = "campaignID"
        public static let localNotificationURL = "localNotificationURL"
    }

    @Published var notifications = [BaseNotification]() {
        didSet {
            saveNotitificationsToDevice(notifications)
        }
    }

    var upcomingNotifications: [BaseNotification] {
        notifications.filter { $0.dateReceived > Date() }
    }

    var readNotifications: [BaseNotification] {
        notifications.filter { !$0.isUnread }
    }

    var unreadNotifications: [BaseNotification] {
        notifications.filter { $0.isUnread && $0.dateReceived <= Date() }
    }

    var shouldShowBadge: Bool {
        unreadNotifications.count > 0
    }

    // MARK: - Updates
    func handleReceivedNotification(_ notification: BaseNotification) {
        notifications.insert(notification, at: 0)
    }

    // MARK: - Storage
    private var storageURL: URL? {
        guard
            let path = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: AppInfo.sharedContainerIdentifier)?.path
        else {
            return nil
        }

        return URL(fileURLWithPath: path).appendingPathComponent("notifications")
    }

    func saveNotitificationsToDevice(_ notifications: [BaseNotification]) {
        guard let path = storageURL?.absoluteString else {
            return
        }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(notifications)
            FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
        } catch {
            logger.info("Failed to save notifications to device: \(error)")
        }
    }

    func retrieveNotificationsFromDevice() -> [BaseNotification] {
        guard let url = storageURL,
            FileManager.default.fileExists(atPath: url.absoluteString),
            let notificationData = try? Data(contentsOf: url)
        else {
            return [BaseNotification]()
        }

        do {
            if let notifications = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(
                notificationData)
                as? [BaseNotification]
            {
                return notifications
            }
        } catch {
            logger.info("Failed to retrieve notifications from device: \(error)")
        }

        return [BaseNotification]()
    }

    /// Deletes all read notifications that are 7+ days old.
    func purgeOldNotifications() {
        notifications = notifications.filter {
            $0.isUnread || $0.dateRead?.daysFromToday() ?? 0 <= 7
        }
    }

    // MARK: - Notification Creation
    func createLocalNotification(
        identifier: String,
        promoId: String,
        type: NotificationType? = nil,
        timeInterval: TimeInterval,
        title: String,
        subtitle: String? = nil,
        body: String?,
        urlStr: String? = nil,
        deeplinkUrl: String? = nil,
        completionHandler: @escaping (Result<BaseNotification, Error>) -> Void
    ) {
        if NeevaFeatureFlags.latestValue(.disableLocalNotification) {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle = subtitle {
            content.subtitle = subtitle
        }
        if let body = body {
            content.body = body
        }
        content.userInfo[NotificationManager.promoIdKey] = promoId
        if let urlStr = urlStr {
            content.userInfo[NotificationManager.notificationKey.localNotificationURL] = urlStr
        }
        if let deeplinkUrl = deeplinkUrl {
            content.userInfo[NotificationManager.notificationKey.deeplinkURL] = deeplinkUrl
        }

        // Create the trigger as a repeating event.
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: false)

        // Create the request
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        // Schedule the request with the system.
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.add(request) { (error) in
            if let error = error {
                completionHandler(.failure(error))
            } else {
                let baseNotification = NeevaPromoNotification(
                    id: identifier, promoId: promoId,
                    type: type, title: title,
                    subtitle: subtitle, body: body,
                    deeplinkUrl: deeplinkUrl,
                    dateReceived: Date(timeIntervalSinceNow: timeInterval))
                self.notifications.append(baseNotification)
                if type == .neevaPromo {
                    Defaults[.lastScheduledNeevaPromoID] = promoId
                }
                completionHandler(.success(baseNotification))
            }
        }
    }

    func cancelLocalNotification(identifier: String) {
        UNUserNotificationCenter
            .current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])

        if let index = notifications.firstIndex(where: { $0.id == identifier }) {
            notifications.remove(at: index)
        }
    }

    func rescheduleNotification(identifier: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { pendingNotifications in
            for notification in pendingNotifications where notification.identifier == identifier {
                self.cancelLocalNotification(identifier: identifier)

                if let trigger = notification.trigger as? UNTimeIntervalNotificationTrigger {
                    self.createLocalNotification(
                        identifier: notification.identifier,
                        promoId:
                            notification.content.userInfo[NotificationManager.promoIdKey] as? String
                            ?? "",
                        timeInterval: trigger.timeInterval,
                        title: notification.content.title, subtitle: notification.content.subtitle,
                        body: notification.content.body
                    ) { _ in }
                }
            }
        }
    }

    private var subscriptions: Set<AnyCancellable> = []

    func setupFeatureFlagUpdateHandler() {
        NeevaFeatureFlags.shared.$flagsUpdated.sink { flagsUpdated in
            if flagsUpdated {
                let notificationContent = NeevaFeatureFlags.latestValue(.localNotificationContent)
                let neevaPromo =
                    LocalNotitifications.parseNotificationPromoContent(content: notificationContent)
                if let neevaPromo = neevaPromo,
                    neevaPromo.promoId != Defaults[.lastScheduledNeevaPromoID]
                {
                    LocalNotitifications.scheduleNeevaPromoCallbackIfAuthorized(
                        callSite: LocalNotitifications.ScheduleCallSite.featureFlagUpdate
                    )
                }
            }
        }.store(in: &subscriptions)
    }

    // MARK: - Notification Handler
    func handleNotification(request: UNNotificationRequest, bvc: BrowserViewController) {
        switch NotificationType(rawValue: request.identifier) {
        case .neevaPromo:
            var tapAction: LocalNotitifications.LocalNotificationTapAction
            if !NeevaUserInfo.shared.isUserLoggedIn {
                bvc.presentIntroViewController(true)
                tapAction = LocalNotitifications.LocalNotificationTapAction.openIntroView
            } else {
                if let urlStr =
                    request.content.userInfo[
                        NotificationManager.notificationKey.localNotificationURL] as? String,
                    let url = URL(string: urlStr)
                {
                    bvc.openURLInNewTab(url)
                    tapAction = LocalNotitifications.LocalNotificationTapAction.openCustomURL
                } else {
                    bvc.openURLInNewTab(NeevaConstants.appWelcomeToursURL)
                    tapAction = LocalNotitifications.LocalNotificationTapAction.openWelcomeTour
                }
            }
            var attributes = [
                ClientLogCounterAttribute(
                    key: LogConfig.NotificationAttribute.localNotificationTapAction,
                    value: tapAction.rawValue)
            ]
            if let promoId = request.content.userInfo[NotificationManager.promoIdKey] as? String {
                attributes.append(
                    ClientLogCounterAttribute(
                        key: LogConfig.NotificationAttribute.localNotificationPromoId,
                        value: promoId)
                )
            }
            ClientLogger.shared.logCounter(
                .OpenLocalNotification,
                attributes: attributes
            )
        case .neevaOnboardingNewsProvider, .neevaOnboardingProductSearch, .neevaOnboardingFastTap:
            var attributes: [ClientLogCounterAttribute] = []
            if let promoId = request.content.userInfo[NotificationManager.promoIdKey] as? String {
                attributes.append(
                    ClientLogCounterAttribute(
                        key: LogConfig.NotificationAttribute.localNotificationPromoId,
                        value: promoId)
                )
            }
            ClientLogger.shared.logCounter(
                .OpenLocalNotification,
                attributes: attributes
            )

            if !NeevaUserInfo.shared.isUserLoggedIn {
                bvc.presentIntroViewController(true)
                return
            } else {
                if let urlStr =
                    request.content.userInfo[NotificationManager.notificationKey.localNotificationURL] as? String,
                    let url = URL(string: urlStr) {
                    bvc.openURLInNewTab(url)
                } else {
                    bvc.openURLInNewTab(NeevaConstants.appWelcomeToursURL)
                }
            }
            break
        case .none:
            break
        }

        // handle deeplink
        if let urlStr = request.content.userInfo[notificationKey.deeplinkURL] as? String,
            let deeplink = URL(string: urlStr),
            let routerpath = NavigationPath(bvc: bvc, url: deeplink)
        {
            NavigationPath.handle(nav: routerpath, with: bvc)
        }

        if let campaignID = request.content.userInfo[notificationKey.campaignID] as? String {
            let attributes = [
                ClientLogCounterAttribute(
                    key: LogConfig.NotificationAttribute.notificationCampaignId,
                    value: campaignID)
            ]
            ClientLogger.shared.logCounter(.OpenNotification, attributes: attributes)
        }
    }

    // MARK: - Init
    init() {
        notifications = retrieveNotificationsFromDevice()
    }
}
