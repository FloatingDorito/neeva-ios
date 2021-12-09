// Copyright Neeva. All rights reserved.

import Defaults
import Foundation
import Shared

public class EnvironmentHelper {
    public static let shared = EnvironmentHelper()

    public var env: ClientLogEnvironment {
        #if DEBUG
            return ClientLogEnvironment(rawValue: "Dev")!
        #else
            return ClientLogEnvironment(rawValue: "Prod")!
        #endif
    }

    public var themeStyle: String {
        switch UIScreen.main.traitCollection.userInterfaceStyle {
        case .dark:
            return "Dark"
        case .light:
            return "Light"
        default:
            return "Unknown"
        }
    }

    public var orientation: String {
        switch UIDevice.current.orientation {
        case .unknown:
            return "Unknown"
        case .portrait:
            return "Portrait"
        case .portraitUpsideDown:
            return "PortraitUpsideDown"
        case .landscapeLeft:
            return "LandscapeLeft"
        case .landscapeRight:
            return "LandscapeRight"
        case .faceUp:
            return "FaceUp"
        case .faceDown:
            return "FaceDown"
        default:
            return "Unknown"
        }
    }

    public var screenSize: String {
        return "\(UIScreen.main.bounds.width) x \(UIScreen.main.bounds.height)"
    }

    public func getAttributes() -> [ClientLogCounterAttribute] {
        var numOfNormalTabs = 0
        var numOfPrivateTabs = 0
        TabManager.all.forEach { tabManager in
            numOfNormalTabs += tabManager.normalTabs.count
            numOfPrivateTabs += tabManager.privateTabs.count
        }

        // number of normal tabs opened
        let normalTabsOpened = ClientLogCounterAttribute(
            key: LogConfig.Attribute.NormalTabsOpened,
            value: String(numOfNormalTabs))

        // number of private tabs opened
        let privateTabsOpened = ClientLogCounterAttribute(
            key: LogConfig.Attribute.PrivateTabsOpened,
            value: String(numOfPrivateTabs))

        // user theme setting
        let deviceTheme = ClientLogCounterAttribute(
            key: LogConfig.Attribute.UserInterfaceStyle, value: self.themeStyle)

        // orientation
        let deviceOrientation = ClientLogCounterAttribute(
            key: LogConfig.Attribute.DeviceOrientation, value: self.orientation)

        // screensize
        let deviceScreensSize = ClientLogCounterAttribute(
            key: LogConfig.Attribute.DeviceScreenSize, value: self.screenSize)

        // is user signed in
        let isUserSignedIn = ClientLogCounterAttribute(
            key: LogConfig.Attribute.isUserSignedIn,
            value: String(NeevaUserInfo.shared.hasLoginCookie()))

        let attributes = [
            normalTabsOpened, privateTabsOpened, deviceTheme, deviceOrientation,
            deviceScreensSize, isUserSignedIn, getSessionUUID(),
        ]
        return attributes
    }

    public func getFirstRunAttributes() -> [ClientLogCounterAttribute] {
        // is user signed in
        let isUserSignedIn = ClientLogCounterAttribute(
            key: LogConfig.Attribute.isUserSignedIn,
            value: String(NeevaUserInfo.shared.hasLoginCookie()))

        // user theme setting
        let deviceTheme = ClientLogCounterAttribute(
            key: LogConfig.Attribute.UserInterfaceStyle, value: self.themeStyle)

        // device name
        let deviceName = ClientLogCounterAttribute(
            key: LogConfig.Attribute.DeviceName, value: NeevaConstants.deviceNameValue)

        // first run path, option user selected on first run screen
        let firstRunPath = ClientLogCounterAttribute(
            key: LogConfig.Attribute.FirstRunPath, value: Defaults[.firstRunPath])

        // count of preview mode query
        let previewQueryCount = ClientLogCounterAttribute(
            key: LogConfig.Attribute.PreviewModeQueryCount,
            value: String(Defaults[.previewModeQueries].count))

        return [
            getSessionUUID(), isUserSignedIn, deviceTheme, deviceName, firstRunPath,
            previewQueryCount,
        ]
    }

    private func getSessionUUID() -> ClientLogCounterAttribute {
        // Rotate session UUID every 30 mins
        if Defaults[.sessionUUIDExpirationTime].minutesFromNow() > 30 {
            Defaults[.sessionUUID] = UUID().uuidString
            Defaults[.sessionUUIDExpirationTime] = Date()
        }

        // session UUID that will rotate every 30 mins
        return ClientLogCounterAttribute(
            key: LogConfig.Attribute.SessionUUID, value: Defaults[.sessionUUID])
    }
}
