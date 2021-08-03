/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import XCGLogger

public struct Logger {}

// MARK: - Singleton Logger Instances
extension Logger {
    public static let logPII = false

    /// Logger used for recording happenings with Sync, Accounts, Providers, Storage, and Profiles
    public static let sync = RollingFileLogger(
        filenameRoot: "sync",
        logDirectoryPath: Logger.logFileDirectoryPath(inDocuments: saveLogsToDocuments))

    /// Logger used for recording frontend/browser happenings
    public static let browser = RollingFileLogger(
        filenameRoot: "browser",
        logDirectoryPath: Logger.logFileDirectoryPath(inDocuments: saveLogsToDocuments))

    /// Logger used for logging database errors such as corruption
    public static let corrupt: RollingFileLogger = {
        let logger = RollingFileLogger(
            filenameRoot: "corruptLogger",
            logDirectoryPath: Logger.logFileDirectoryPath(inDocuments: saveLogsToDocuments))
        logger.newLogWithDate(Date())
        return logger
    }()

    /// Save logs to `~/Documents` folder. If this is `true`, the flag is reset in `UserDefaults` so it does not persist to the next launch.
    public static let saveLogsToDocuments: Bool = {
        let value = UserDefaults.standard.bool(forKey: "SettingsBundleSaveLogsToDocuments")
        if value {
            UserDefaults.standard.set(false, forKey: "SettingsBundleSaveLogsToDocuments")
        }
        return value
    }()

    public static func copyPreviousLogsToDocuments() {
        if let defaultLogDirectoryPath = logFileDirectoryPath(inDocuments: false),
            let documentsLogDirectoryPath = logFileDirectoryPath(inDocuments: true),
            let previousLogFiles = try? FileManager.default.contentsOfDirectory(
                atPath: defaultLogDirectoryPath)
        {
            let defaultLogDirectoryURL = URL(
                fileURLWithPath: defaultLogDirectoryPath, isDirectory: true)
            let documentsLogDirectoryURL = URL(
                fileURLWithPath: documentsLogDirectoryPath, isDirectory: true)
            for previousLogFile in previousLogFiles {
                let previousLogFileURL = defaultLogDirectoryURL.appendingPathComponent(
                    previousLogFile)
                let targetLogFileURL = documentsLogDirectoryURL.appendingPathComponent(
                    previousLogFile)
                try? FileManager.default.copyItem(at: previousLogFileURL, to: targetLogFileURL)
            }
        }
    }

    /// Return the log file directory path. If the directory doesn't exist, make sure it exist first before returning the path.
    /// - returns: Directory path where log files are stored
    public static func logFileDirectoryPath(inDocuments: Bool) -> String? {
        let searchPathDirectory: FileManager.SearchPathDirectory =
            inDocuments ? .documentDirectory : .cachesDirectory
        if let targetDirectory = NSSearchPathForDirectoriesInDomains(
            searchPathDirectory, .userDomainMask, true
        ).first {
            let logsDirectory = "\(targetDirectory)/Logs"
            if !FileManager.default.fileExists(atPath: logsDirectory) {
                do {
                    try FileManager.default.createDirectory(
                        atPath: logsDirectory, withIntermediateDirectories: true, attributes: nil)
                    return logsDirectory
                } catch _ as NSError {
                    return nil
                }
            } else {
                return logsDirectory
            }
        }

        return nil
    }

    static private func fileLoggerWithName(_ name: String) -> XCGLogger {
        let log = XCGLogger()
        if let logFileURL = urlForLogNamed(name) {
            let fileDestination = FileDestination(
                owner: log,
                writeToFile: logFileURL.absoluteString,
                identifier: "co.neeva.app.ios.browser.filelogger.\(name)"
            )
            log.add(destination: fileDestination)
        }
        return log
    }

    static private func urlForLogNamed(_ name: String) -> URL? {
        guard let logDir = Logger.logFileDirectoryPath(inDocuments: saveLogsToDocuments) else {
            return nil
        }

        return URL(string: "\(logDir)/\(name).log")
    }
}
