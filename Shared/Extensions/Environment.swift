// Copyright Neeva. All rights reserved.

import SwiftUI

// The `openURL` environment key is not writable, so we need to roll our own.
extension EnvironmentValues {
    private struct OnOpenURLKey: EnvironmentKey {
        static var defaultValue: ((URL) -> Void)? = nil
    }

    /// Provide this environment key to open URLs in an app other than Safari.
    public var onOpenURL: (URL) -> Void {
        get { self[OnOpenURLKey] ?? { openURL($0) } }
        set { self[OnOpenURLKey] = newValue }
    }

    private struct OnOpenURLForSpaceKey: EnvironmentKey {
        static var defaultValue: ((URL, String) -> Void)? = nil
    }

    public var onOpenURLForSpace: (URL, String) -> Void {
        get { self[OnOpenURLForSpaceKey] ?? { url, _ in openURL(url) } }
        set { self[OnOpenURLForSpaceKey] = newValue }
    }

    private struct LogAuth: EnvironmentKey {
        static var defaultValue: ((Bool) -> Void)? = nil
    }
    public var logAuth: (Bool) -> Void {
        get {
            self[LogAuth] ?? { _ in fatalError(".environment(\\.logSignIn) must be specified") }
        }
        set { self[LogAuth] = newValue }
    }
}
