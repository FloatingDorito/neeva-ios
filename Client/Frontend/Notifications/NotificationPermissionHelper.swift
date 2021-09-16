// Copyright Neeva. All rights reserved.

import Foundation
import UserNotifications

class NotificationPermissionHelper {
    static let shared = NotificationPermissionHelper()

    func didAlreadyRequestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus != .notDetermined)
            }
        }
    }

    func isAuthorized(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            completion(
                settings.authorizationStatus != .denied
                    && settings.authorizationStatus != .notDetermined)
        }
    }

    func requestPermissionIfNeeded(completion: (() -> Void)? = nil,
                                   openSettingsIfNeeded: Bool = false) {
        isAuthorized { [self] authorized in
            guard !authorized else {
                completion?()
                return
            }

            didAlreadyRequestPermission { requested in
                if !requested {
                    ClientLogger.shared.logCounter(.ShowSystemNotificationPrompt)
                    requestPermissionFromSystem(completion: completion)
                } else if openSettingsIfNeeded {
                    /// If we can't show the iOS system notification because the user denied our first request,
                    /// this will take them to system settings to enable notifications there.
                    SystemsHelper.openSystemSettingsNeevaPage()
                    completion?()
                }
            }
        }
    }

    /// Shows the iOS system popup to request notification permission.
    /// Will only show **once**, and if the user has not denied permission already.
    func requestPermissionFromSystem(completion: (() -> Void)? = nil) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [
                .alert, .sound, .badge, .providesAppNotificationSettings,
            ]) { granted, _ in
                print("Notification permission granted: \(granted)")
                DispatchQueue.main.async {
                    ClientLogger.shared.logCounter(
                        granted
                            ? .AuthorizeSystemNotification
                            : .DenySystemNotification
                    )
                }

                completion?()

                guard granted else { return }
                self.getNotificationSettings()
            }
    }

    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Notification settings: \(settings)")
            guard settings.authorizationStatus == .authorized else { return }

            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func unregisterRemoteNotifications() {
        UIApplication.shared.unregisterForRemoteNotifications()
    }
}
