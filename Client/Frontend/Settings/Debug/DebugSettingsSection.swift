// Copyright Neeva. All rights reserved.

import Defaults
import Shared
import SwiftUI

struct DebugSettingsSection: View {
    @Environment(\.onOpenURL) var openURL
    @Environment(\.dismissScreen) var dimissScreen
    @Default(.enableGeigerCounter) var enableGeigerCounter

    var body: some View {
        Group {
            Section(header: Text("Debug — Neeva")) {
                NavigationLink(
                    "Server Feature Flags",
                    destination: NeevaFeatureFlagSettingsView().navigationTitle(
                        "Server Feature Flags"))
                NavigationLink(
                    "Server User Flags",
                    destination: NeevaUserFlagSettingsView().navigationTitle(
                        "Server User Flags"))
                AppHostSetting()
                NavigationLinkButton("Neeva Admin") {
                    openURL(NeevaConstants.appHomeURL / "admin")
                }
            }
            Section(header: Text("Debug — Local")) {
                NavigationLink(
                    "Local Feature Flags",
                    destination: FeatureFlagSettingsView().navigationTitle("Local Feature Flags"))
                NavigationLink(
                    "Internal Settings",
                    destination: InternalSettingsView().navigationTitle("Internal Settings"))
                NavigationLink(
                    "Logging",
                    destination: LoggingSettingsView().navigationTitle("Logging"))
                Toggle("Enable Geiger Counter", isOn: $enableGeigerCounter)
                    .onChange(of: enableGeigerCounter) {
                        if $0 {
                            SceneDelegate.getCurrentSceneDelegate(for: nil).startGeigerCounter()
                        } else {
                            SceneDelegate.getCurrentSceneDelegate(for: nil).stopGeigerCounter()
                        }
                    }
                NavigationLink(
                    "Schedule Notification",
                    destination: ScheduleNotificationView()
                        .navigationTitle("Schedule Notification"))
                Button {
                    dimissScreen()
                    SceneDelegate.getBVC(for: nil).showAsModalOverlaySheet(
                        style: OverlayStyle(
                            showTitle: false,
                            backgroundColor: .systemBackground)
                    ) {
                        NotificationPromptViewOverlayContent()
                    } onDismiss: {
                    }
                } label: {
                    Text("Show Welcome Tour Notification Prompt")
                        .foregroundColor(Color.label)
                }

                if let token = Defaults[.notificationToken] {
                    HStack {
                        Text("Notification Token")
                        Text(token)
                            .withFont(.bodySmall)
                            .contextMenu(
                                ContextMenu(menuItems: {
                                    Button(
                                        "Copy",
                                        action: {
                                            UIPasteboard.general.string = token
                                        })
                                }))
                    }
                }
            }
            DebugDBSettingsSection()
            DecorativeSection {
                Button("Force Crash App") {
                    Sentry.shared.crash()
                }.accentColor(.red)
            }
        }
        .listRowBackground(Color.red.opacity(0.2).ignoresSafeArea())
    }
}

struct DebugSettingsSection_Previews: PreviewProvider {
    static var previews: some View {
        SettingPreviewWrapper {
            DebugSettingsSection()
        }
    }
}
