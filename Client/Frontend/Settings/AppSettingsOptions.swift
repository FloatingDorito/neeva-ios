/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared
import SwiftKeychainWrapper
import LocalAuthentication
import MozillaAppServices
import NeevaSupport

// This file contains all of the settings available in the main settings screen of the app.

private var ShowDebugSettings: Bool = false
private var DebugSettingsClickCount: Int = 0

private var disclosureIndicator: UIImageView {
    let disclosureIndicator = UIImageView()
    disclosureIndicator.image = UIImage(named: "menu-Disclosure")?.withRenderingMode(.alwaysTemplate)
    disclosureIndicator.tintColor = UIColor.theme.tableView.accessoryViewTint
    disclosureIndicator.sizeToFit()
    return disclosureIndicator
}

// For great debugging!
class HiddenSetting: Setting {
    unowned let settings: SettingsTableViewController

    init(settings: SettingsTableViewController) {
        self.settings = settings
        super.init(title: nil)
    }

    override var hidden: Bool {
        return !ShowDebugSettings
    }
}

class DeleteExportedDataSetting: HiddenSetting {
    override var title: NSAttributedString? {
        // Not localized for now.
        return NSAttributedString(string: "Debug: delete exported databases", attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText])
    }

    override func onClick(_ navigationController: UINavigationController?) {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(atPath: documentsPath)
            for file in files {
                if file.hasPrefix("browser.") || file.hasPrefix("logins.") {
                    try fileManager.removeItemInDirectory(documentsPath, named: file)
                }
            }
        } catch {
            print("Couldn't delete exported data: \(error).")
        }
    }
}

class ExportBrowserDataSetting: HiddenSetting {
    override var title: NSAttributedString? {
        // Not localized for now.
        return NSAttributedString(string: "Debug: copy databases to app container", attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText])
    }

    override func onClick(_ navigationController: UINavigationController?) {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        do {
            let log = Logger.syncLogger
            try self.settings.profile.files.copyMatching(fromRelativeDirectory: "", toAbsoluteDirectory: documentsPath) { file in
                log.debug("Matcher: \(file)")
                return file.hasPrefix("browser.") || file.hasPrefix("logins.") || file.hasPrefix("metadata.")
            }
        } catch {
            print("Couldn't export browser data: \(error).")
        }
    }
}

class ExportLogDataSetting: HiddenSetting {
    override var title: NSAttributedString? {
        // Not localized for now.
        return NSAttributedString(string: "Debug: copy log files to app container", attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText])
    }

    override func onClick(_ navigationController: UINavigationController?) {
        Logger.copyPreviousLogsToDocuments()
    }
}

/*
 FeatureSwitchSetting is a boolean switch for features that are enabled via a FeatureSwitch.
 These are usually features behind a partial release and not features released to the entire population.
 */
class FeatureSwitchSetting: BoolSetting {
    let featureSwitch: FeatureSwitch
    let prefs: Prefs

    init(prefs: Prefs, featureSwitch: FeatureSwitch, with title: NSAttributedString) {
        self.featureSwitch = featureSwitch
        self.prefs = prefs
        super.init(prefs: prefs, defaultValue: featureSwitch.isMember(prefs), attributedTitleText: title)
    }

    override var hidden: Bool {
        return !ShowDebugSettings
    }

    override func displayBool(_ control: UISwitch) {
        control.isOn = featureSwitch.isMember(prefs)
    }

    override func writeBool(_ control: UISwitch) {
        self.featureSwitch.setMembership(control.isOn, for: self.prefs)
    }

}

class NeevaHostSetting: HiddenSetting {
    override var title: NSAttributedString? {
        NSAttributedString(string: "Debug: Neeva server (currently \(NeevaConstants.appHost))", attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText])
    }
    override func onClick(_ navigationController: UINavigationController?) {
        let alert = UIAlertController(title: "Enter custom Neeva server", message: "Default is alpha.neeva.co", preferredStyle: .alert)
        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            NeevaConstants.appHost = alert.textFields!.first!.text!
        }

        alert.addAction(saveAction)
        alert.addTextField { tf in
            tf.placeholder = "Neeva server domain (required)"
            tf.text = NeevaConstants.appHost
            tf.keyboardType = .URL
            tf.clearButtonMode = .always
            if #available(iOS 14, *) {
                tf.addAction(UIAction { _ in
                    saveAction.isEnabled = tf.hasText
                }, for: .editingChanged)

                tf.returnKeyType = .done
                tf.addAction(UIAction { _ in
                    saveAction.accessibilityActivate()
                }, for: .primaryActionTriggered)
            }
        }
        navigationController!.present(alert, animated: true, completion: nil)
    }
} 

class ForceCrashSetting: HiddenSetting {
    override var title: NSAttributedString? {
        return NSAttributedString(string: "Debug: Force Crash", attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText])
    }

    override func onClick(_ navigationController: UINavigationController?) {
        Sentry.shared.crash()
    }
}

class ChangeToChinaSetting: HiddenSetting {
    override var title: NSAttributedString? {
        return NSAttributedString(string: "Debug: toggle China version (needs restart)", attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText])
    }

    override func onClick(_ navigationController: UINavigationController?) {
        if UserDefaults.standard.bool(forKey: debugPrefIsChinaEdition) {
            UserDefaults.standard.removeObject(forKey: debugPrefIsChinaEdition)
        } else {
            UserDefaults.standard.set(true, forKey: debugPrefIsChinaEdition)
        }
    }
}

class SlowTheDatabase: HiddenSetting {
    override var title: NSAttributedString? {
        return NSAttributedString(string: "Debug: simulate slow database operations", attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText])
    }

    override func onClick(_ navigationController: UINavigationController?) {
        debugSimulateSlowDBOperations = !debugSimulateSlowDBOperations
    }
}

class SentryIDSetting: HiddenSetting {
    let deviceAppHash = UserDefaults(suiteName: AppInfo.sharedContainerIdentifier)?.string(forKey: "SentryDeviceAppHash") ?? "0000000000000000000000000000000000000000"
    override var title: NSAttributedString? {
        return NSAttributedString(string: "Sentry ID: \(deviceAppHash)", attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10)])
    }

    override func onClick(_ navigationController: UINavigationController?) {
        copyAppDeviceIDAndPresentAlert(by: navigationController)
    }

    func copyAppDeviceIDAndPresentAlert(by navigationController: UINavigationController?) {
        let alertTitle = Strings.SettingsCopyAppVersionAlertTitle
        let alert = AlertController(title: alertTitle, message: nil, preferredStyle: .alert)
        getSelectedCell(by: navigationController)?.setSelected(false, animated: true)
        UIPasteboard.general.string = deviceAppHash
        navigationController?.topViewController?.present(alert, animated: true) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                alert.dismiss(animated: true)
            }
        }
    }

    func getSelectedCell(by navigationController: UINavigationController?) -> UITableViewCell? {
        let controller = navigationController?.topViewController
        let tableView = (controller as? AppSettingsTableViewController)?.tableView
        guard let indexPath = tableView?.indexPathForSelectedRow else { return nil }
        return tableView?.cellForRow(at: indexPath)
    }
}

class ShowEtpCoverSheet: HiddenSetting {
    let profile: Profile
    
    override var title: NSAttributedString? {
        return NSAttributedString(string: "Debug: ETP Cover Sheet On", attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText])
    }
    
    override init(settings: SettingsTableViewController) {
        self.profile = settings.profile
        super.init(settings: settings)
    }
    
    override func onClick(_ navigationController: UINavigationController?) {
        BrowserViewController.foregroundBVC().hasTriedToPresentETPAlready = false
        // ETP is shown when user opens app for 3rd time on clean install.
        // Hence setting session to 2 (0,1,2) for 3rd install as it starts from 0 being 1st session
        self.profile.prefs.setInt(2, forKey: PrefsKeys.KeyInstallSession)
        self.profile.prefs.setString(ETPCoverSheetShowType.CleanInstall.rawValue, forKey: PrefsKeys.KeyETPCoverSheetShowType)
    }
}

class LeanplumStatus: HiddenSetting {
    let lplumSetupType = LeanPlumClient.shared.lpSetupType()
    override var title: NSAttributedString? {
        return NSAttributedString(string: "LP Setup: \(lplumSetupType) | Started: \(LeanPlumClient.shared.isRunning()) | Device ID: \(LeanPlumClient.shared.leanplumDeviceId ?? "")", attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText])
    }
    
    override func onClick(_ navigationController: UINavigationController?) {
        copyLeanplumDeviceIDAndPresentAlert(by: navigationController)
    }
    
    func copyLeanplumDeviceIDAndPresentAlert(by navigationController: UINavigationController?) {
        let alertTitle = Strings.SettingsCopyAppVersionAlertTitle
        let alert = AlertController(title: alertTitle, message: nil, preferredStyle: .alert)
        UIPasteboard.general.string = "\(LeanPlumClient.shared.leanplumDeviceId ?? "")"
        navigationController?.topViewController?.present(alert, animated: true) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                alert.dismiss(animated: true)
            }
        }
    }
}

///Note: We have disabed it until we find best way to test newTabToolbarButton
//class ToggleNewTabToolbarButton: HiddenSetting {
//    override var title: NSAttributedString? {
//        return NSAttributedString(string: "Debug: Toggle new tab toolbar button", attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText])
//    }
//
//    override func onClick(_ navigationController: UINavigationController?) {
//        let currentValue = settings.profile.prefs.boolForKey(PrefsKeys.ShowNewTabToolbarButton) ?? false
//        settings.profile.prefs.setBool(!currentValue, forKey: PrefsKeys.ShowNewTabToolbarButton)
//    }
//}

class ToggleChronTabs: HiddenSetting {
    override var title: NSAttributedString? {
        // If we are running an A/B test this will also fetch the A/B test variables from leanplum. Re-open app to see the effect.
        return NSAttributedString(string: "Debug: Toggle chronological tabs", attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText])
    }

    override func onClick(_ navigationController: UINavigationController?) {
        let currentValue = settings.profile.prefs.boolForKey(PrefsKeys.ChronTabsPrefKey) ?? false
        settings.profile.prefs.setBool(!currentValue, forKey: PrefsKeys.ChronTabsPrefKey)
    }
}

// Show the current version of Firefox
class VersionSetting: Setting {
    unowned let settings: SettingsTableViewController

    override var accessibilityIdentifier: String? { return "FxVersion" }

    init(settings: SettingsTableViewController) {
        self.settings = settings
        super.init(title: nil)
    }

    override var title: NSAttributedString? {
        return NSAttributedString(string: "\(AppName.longName) \(VersionSetting.appVersion) (\(VersionSetting.appBuildNumber))", attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText])
    }
    
    public static var appVersion: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }
    
    public static var appBuildNumber: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    }

    override func onConfigureCell(_ cell: UITableViewCell) {
        super.onConfigureCell(cell)
    }

    override func onClick(_ navigationController: UINavigationController?) {
        DebugSettingsClickCount += 1
        if DebugSettingsClickCount >= 5 {
            DebugSettingsClickCount = 0
            ShowDebugSettings = !ShowDebugSettings
            settings.tableView.reloadData()
        }
    }

    override func onLongPress(_ navigationController: UINavigationController?) {
        copyAppVersionAndPresentAlert(by: navigationController)
    }

    func copyAppVersionAndPresentAlert(by navigationController: UINavigationController?) {
        let alertTitle = Strings.SettingsCopyAppVersionAlertTitle
        let alert = AlertController(title: alertTitle, message: nil, preferredStyle: .alert)
        getSelectedCell(by: navigationController)?.setSelected(false, animated: true)
        UIPasteboard.general.string = self.title?.string
        navigationController?.topViewController?.present(alert, animated: true) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                alert.dismiss(animated: true)
            }
        }
    }
    
    func getSelectedCell(by navigationController: UINavigationController?) -> UITableViewCell? {
        let controller = navigationController?.topViewController
        let tableView = (controller as? AppSettingsTableViewController)?.tableView
        guard let indexPath = tableView?.indexPathForSelectedRow else { return nil }
        return tableView?.cellForRow(at: indexPath)
    }
}

// Opens the license page in a new tab
class LicenseAndAcknowledgementsSetting: Setting {
    override var title: NSAttributedString? {
        return NSAttributedString(string: .AppSettingsLicenses, attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText])
    }

    override var url: URL? {
        return URL(string: "\(InternalURL.baseUrl)/\(AboutLicenseHandler.path)")
    }

    override func onClick(_ navigationController: UINavigationController?) {
        setUpAndPushSettingsContentViewController(navigationController, self.url)
    }
}

// Opens about:rights page in the content view controller
class YourRightsSetting: Setting {
    override var title: NSAttributedString? {
        return NSAttributedString(string: .AppSettingsYourRights, attributes:
            [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText])
    }

    override var url: URL? {
        return URL(string: "https://neeva.co/terms")
    }

    override func onClick(_ navigationController: UINavigationController?) {
        setUpAndPushSettingsContentViewController(navigationController, self.url)
    }
}

// Opens the on-boarding screen again
class ShowIntroductionSetting: Setting {
    let profile: Profile

    override var accessibilityIdentifier: String? { return "ShowTour" }

    init(settings: SettingsTableViewController) {
        self.profile = settings.profile
        super.init(title: NSAttributedString(string: NSLocalizedString("Show Tour", comment: "Show the on-boarding screen again from the settings"), attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText]))
    }

    override func onClick(_ navigationController: UINavigationController?) {
        navigationController?.dismiss(animated: true, completion: {
            BrowserViewController.foregroundBVC().presentIntroViewController(true)
        })
    }
}

class SendFeedbackSetting: Setting {
    override var title: NSAttributedString? {
        return NSAttributedString(string: .AppSettingsSendFeedback, attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText])
    }

    override var url: URL? {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        return URL(string: "https://input.neeva.co/feedback/fxios/\(appVersion)")
    }

    override func onClick(_ navigationController: UINavigationController?) {
        setUpAndPushSettingsContentViewController(navigationController, self.url)
    }
}

// Opens the SUMO page in a new tab
class OpenSupportPageSetting: Setting {
    init(delegate: SettingsDelegate?) {
        super.init(title: NSAttributedString(string: .AppSettingsHelp, attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText]),
            delegate: delegate)
    }

    override func onClick(_ navigationController: UINavigationController?) {
        navigationController?.dismiss(animated: true) {
            if let url = URL(string: "https://neeva.co/contact") {
                self.delegate?.settingsOpenURLInNewTab(url)
            }
        }
    }
}

class ContentBlockerSetting: Setting {
    let profile: Profile
    var tabManager: TabManager!
    override var accessoryView: UIImageView? { return disclosureIndicator }
    override var accessibilityIdentifier: String? { return "TrackingProtection" }

    init(settings: SettingsTableViewController) {
        self.profile = settings.profile
        self.tabManager = settings.tabManager
        super.init(title: NSAttributedString(string: Strings.SettingsTrackingProtectionSectionName, attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText]))
    }

    override func onClick(_ navigationController: UINavigationController?) {
        let viewController = ContentBlockerSettingViewController(prefs: profile.prefs)
        viewController.profile = profile
        viewController.tabManager = tabManager
        navigationController?.pushViewController(viewController, animated: true)
    }
}

class ClearPrivateDataSetting: Setting {
    let profile: Profile
    var tabManager: TabManager!

    override var accessoryView: UIImageView? { return disclosureIndicator }

    override var accessibilityIdentifier: String? { return "ClearPrivateData" }

    init(settings: SettingsTableViewController) {
        self.profile = settings.profile
        self.tabManager = settings.tabManager

        let clearTitle = Strings.SettingsDataManagementSectionName
        super.init(title: NSAttributedString(string: clearTitle, attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText]))
    }

    override func onClick(_ navigationController: UINavigationController?) {
        let viewController = ClearPrivateDataTableViewController()
        viewController.profile = profile
        viewController.tabManager = tabManager
        navigationController?.pushViewController(viewController, animated: true)
    }
}

class PrivacyPolicySetting: Setting {
    override var title: NSAttributedString? {
        return NSAttributedString(string: .AppSettingsPrivacyPolicy, attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText])
    }

    override var url: URL? {
        return URL(string: "https://neeva.co/privacy")
    }

    override func onClick(_ navigationController: UINavigationController?) {
        setUpAndPushSettingsContentViewController(navigationController, self.url)
    }
}

class NewTabPageSetting: Setting {
    let profile: Profile

    override var accessoryView: UIImageView? { return disclosureIndicator }

    override var accessibilityIdentifier: String? { return "NewTab" }

    override var status: NSAttributedString {
        return NSAttributedString(string: NewTabAccessors.getNewTabPage(self.profile.prefs).settingTitle)
    }

    override var style: UITableViewCell.CellStyle { return .value1 }

    init(settings: SettingsTableViewController) {
        self.profile = settings.profile
        super.init(title: NSAttributedString(string: Strings.SettingsNewTabSectionName, attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText]))
    }

    override func onClick(_ navigationController: UINavigationController?) {
        let viewController = NewTabContentSettingsViewController(prefs: profile.prefs)
        viewController.profile = profile
        navigationController?.pushViewController(viewController, animated: true)
    }
}

fileprivate func getDisclosureIndicator() -> UIImageView {
    let disclosureIndicator = UIImageView()
    disclosureIndicator.image = UIImage(named: "menu-Disclosure")?.withRenderingMode(.alwaysTemplate)
    disclosureIndicator.tintColor = UIColor.theme.tableView.accessoryViewTint
    disclosureIndicator.sizeToFit()
    return disclosureIndicator
}

class HomeSetting: Setting {
    let profile: Profile

    override var accessoryView: UIImageView {
        getDisclosureIndicator()
    }
    
    override var accessibilityIdentifier: String? { return "Home" }

    override var status: NSAttributedString {
        return NSAttributedString(string: NewTabAccessors.getHomePage(self.profile.prefs).settingTitle)
    }

    override var style: UITableViewCell.CellStyle { return .value1 }

    init(settings: SettingsTableViewController) {
        self.profile = settings.profile

        super.init(title: NSAttributedString(string: Strings.AppMenuOpenHomePageTitleString, attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText]))
    }

    override func onClick(_ navigationController: UINavigationController?) {
        let viewController = HomePageSettingViewController(prefs: profile.prefs)
        viewController.profile = profile
        navigationController?.pushViewController(viewController, animated: true)
    }
}

@available(iOS 12.0, *)
class SiriPageSetting: Setting {
    let profile: Profile

    override var accessoryView: UIImageView? { return disclosureIndicator }

    override var accessibilityIdentifier: String? { return "SiriSettings" }

    init(settings: SettingsTableViewController) {
        self.profile = settings.profile

        super.init(title: NSAttributedString(string: Strings.SettingsSiriSectionName, attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText]))
    }

    override func onClick(_ navigationController: UINavigationController?) {
        let viewController = SiriSettingsViewController(prefs: profile.prefs)
        viewController.profile = profile
        navigationController?.pushViewController(viewController, animated: true)
    }
}

@available(iOS 14.0, *)
class DefaultBrowserSetting: Setting {
    override var accessibilityIdentifier: String? { return "DefaultBrowserSettings" }

    init() {
        super.init(title: NSAttributedString(string: String.DefaultBrowserMenuItem, attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowActionAccessory]))
    }

    override func onClick(_ navigationController: UINavigationController?) {
        TelemetryWrapper.gleanRecordEvent(category: .action, method: .open, object: .settingsMenuSetAsDefaultBrowser)
        LeanPlumClient.shared.track(event: .settingsSetAsDefaultBrowser)
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:])
    }
}

class OpenWithSetting: Setting {
    let profile: Profile

    override var accessoryView: UIImageView? { return disclosureIndicator }

    override var accessibilityIdentifier: String? { return "OpenWith.Setting" }

    override var status: NSAttributedString {
        guard let provider = self.profile.prefs.stringForKey(PrefsKeys.KeyMailToOption), provider != "mailto:" else {
            return NSAttributedString(string: "")
        }
        if let path = Bundle.main.path(forResource: "MailSchemes", ofType: "plist"), let dictRoot = NSArray(contentsOfFile: path) {
            let mailProvider = dictRoot.compactMap({$0 as? NSDictionary }).first { (dict) -> Bool in
                return (dict["scheme"] as? String) == provider
            }
            return NSAttributedString(string: (mailProvider?["name"] as? String) ?? "")
        }
        return NSAttributedString(string: "")
    }

    override var style: UITableViewCell.CellStyle { return .value1 }

    init(settings: SettingsTableViewController) {
        self.profile = settings.profile

        super.init(title: NSAttributedString(string: Strings.SettingsOpenWithSectionName, attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText]))
    }

    override func onClick(_ navigationController: UINavigationController?) {
        let viewController = OpenWithSettingsViewController(prefs: profile.prefs)
        navigationController?.pushViewController(viewController, animated: true)
    }
}

class ThemeSetting: Setting {
    let profile: Profile
    override var accessoryView: UIImageView? { return disclosureIndicator }
    override var style: UITableViewCell.CellStyle { return .value1 }
    override var accessibilityIdentifier: String? { return "DisplayThemeOption" }

    override var status: NSAttributedString {
        if ThemeManager.instance.systemThemeIsOn {
            return NSAttributedString(string: Strings.SystemThemeSectionHeader)
        } else if !ThemeManager.instance.automaticBrightnessIsOn {
            return NSAttributedString(string: Strings.DisplayThemeManualStatusLabel)
        } else if ThemeManager.instance.automaticBrightnessIsOn {
            return NSAttributedString(string: Strings.DisplayThemeAutomaticStatusLabel)
        }
        return NSAttributedString(string: "")
    }

    init(settings: SettingsTableViewController) {
        self.profile = settings.profile
        super.init(title: NSAttributedString(string: Strings.SettingsDisplayThemeTitle, attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText]))
    }

    override func onClick(_ navigationController: UINavigationController?) {
        navigationController?.pushViewController(ThemeSettingsController(), animated: true)
    }
}

