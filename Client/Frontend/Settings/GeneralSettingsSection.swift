// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Defaults
import Shared
import SwiftUI

struct DetailedSettingsLabel: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
            Text(description)
                .foregroundColor(.secondaryLabel)
                .font(.caption)
        }
    }
}

struct GeneralSettingsSection: View {
    @Default(.showSearchSuggestions) var showSearchSuggestions
    @Default(.blockPopups) var blockPopups
    @Default(.contextMenuShowLinkPreviews) var showLinkPreviews

    var body: some View {
        NavigationLink(
            "Default Browser",
            destination:
                DefaultBrowserOnboardingView(openSettings: {
                    UIApplication.shared.open(
                        URL(string: UIApplication.openSettingsURLString)!, options: [:])
                }, triggerFrom: .settings)
                .onAppear {
                    ClientLogger.shared.logCounter(
                        .SettingDefaultBrowser, attributes: EnvironmentHelper.shared.getAttributes()
                    )
                }
        )
        if FeatureFlag[.customSearchEngine] {
            makeNavigationLink(title: "Search Engine") {
                SearchEngineSettings()
            }
        }
        Toggle("Show Search Suggestions", isOn: $showSearchSuggestions)
        Toggle("Block Pop-up Windows", isOn: $blockPopups)
        Toggle(isOn: $showLinkPreviews) {
            DetailedSettingsLabel(
                title: "Show Link Previews",
                description: "When Long-pressing Links"
            )
        }
    }
}

struct GeneralSettingsSection_Previews: PreviewProvider {
    static var previews: some View {
        SettingPreviewWrapper {
            Section(header: Text("General")) {
                GeneralSettingsSection()
            }
        }
    }
}
