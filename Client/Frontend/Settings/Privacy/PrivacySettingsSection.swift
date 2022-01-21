// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Defaults
import Shared
import SwiftUI

struct PrivacySettingsSection: View {
    @Default(.closePrivateTabs) var closePrivateTabs
    @Default(.contentBlockingEnabled) private var contentBlockingEnabled
    @Environment(\.onOpenURL) var openURL

    var body: some View {
        NavigationLink(
            "Clear Browsing Data",
            destination: DataManagementView()
                .onAppear {
                    ClientLogger.shared.logCounter(
                        .ViewDataManagement, attributes: EnvironmentHelper.shared.getAttributes())
                }
        )
        Toggle(isOn: $closePrivateTabs) {
            DetailedSettingsLabel(
                title: "Close Incognito Tabs",
                description: "When Leaving Incognito Mode"
            )
        }
        if FeatureFlag[.newTrackingProtectionSettings] {
            makeNavigationLink(title: "Tracking Protection") {
                List {
                    Section(header: Text("Global Privacy Settings").padding(.top, 21)) {
                        TrackingSettingsBlock()
                    }
                    TrackingAttribution()
                }
                .listStyle(.insetGrouped)
                .applyToggleStyle()
                .onAppear {
                    ClientLogger.shared.logCounter(
                        .ViewTrackingProtection,
                        attributes: EnvironmentHelper.shared.getAttributes())
                }
            }
        } else {
            Toggle("Tracking Protection", isOn: $contentBlockingEnabled)
                .onChange(of: contentBlockingEnabled) { enabled in
                    ClientLogger.shared.logCounter(
                        enabled ? .TurnOnGlobalBlockTracking : .TurnOffGlobalBlockTracking,
                        attributes: EnvironmentHelper.shared.getAttributes()
                    )
                }
        }
        NavigationLinkButton("Privacy Policy") {
            ClientLogger.shared.logCounter(
                .ViewPrivacyPolicy, attributes: EnvironmentHelper.shared.getAttributes())
            openURL(NeevaConstants.appPrivacyURL)
        }
    }
}

struct PrivacySettingsSection_Previews: PreviewProvider {
    static var previews: some View {
        SettingPreviewWrapper {
            Section(header: Text("Privacy")) {
                PrivacySettingsSection()
            }
        }
    }
}
