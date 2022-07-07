// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Shared
import SwiftUI

struct NeevaAccountInfoView: View {
    @EnvironmentObject var browserModel: BrowserModel
    @Environment(\.onOpenURL) var openURL

    @State var signingOut = false
    @Binding var isPresented: Bool
    @ObservedObject var userInfo: NeevaUserInfo
    @State var showingPremium = false

    var body: some View {
        List {
            Section(header: Text("Signed in to Neeva with")) {
                HStack {
                    (userInfo.authProvider?.icon ?? Image("placeholder-avatar"))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .padding(.trailing, 14)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(userInfo.authProvider?.displayName ?? "Unknown")
                        Text(userInfo.email ?? "")
                            .font(.footnote)
                            .foregroundColor(.secondaryLabel)
                    }
                    .padding(.vertical, 5)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(Text(userInfo.authProvider?.displayName ?? "Unknown")), \(userInfo.email ?? "")"
                )
            }.accessibilityElement(children: .combine)

            Section(header: Text("Membership Status"), footer: membershipStatusFooterText) {
                membershipStatusBody

                if #available(iOS 15, *) {
                    NavigationLink(
                        destination: NeevaPremium(),
                        isActive: $showingPremium
                    ) {
                        HStack {
                            Text("Your Subscription")
                            Spacer()
                            Text("Free")
                        }
                    }
                } else {
                    /*
                     TODO: if a user is paying and payment source is apple,
                     but this is an older OS, should we add a message to the user?
                     */
                }
            }

            DecorativeSection {
                Button("Sign Out") { signingOut = true }
                    .actionSheet(isPresented: $signingOut) {
                        ActionSheet(
                            title: Text("Sign out of Neeva?"),
                            buttons: [
                                .destructive(Text("Sign Out")) {
                                    ClientLogger.shared.logCounter(
                                        .SettingSignout,
                                        attributes: EnvironmentHelper.shared.getAttributes())

                                    if userInfo.hasLoginCookie() {
                                        NotificationPermissionHelper.shared
                                            .deleteDeviceTokenFromServer()

                                        userInfo.clearCache()
                                        userInfo.deleteLoginCookie()
                                        userInfo.didLogOut()
                                        browserModel.tabManager.clearNeevaTabs()

                                        isPresented = false
                                    }
                                },
                                .cancel(),
                            ])
                    }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(userInfo.displayName ?? "Neeva Account")
    }

    private var membershipStatusFooterText: some View {
        switch userInfo.subscriptionType {
        case .basic:
            return EmptyView()
        case .premium, .lifetime:
            /*
             TODO: when the GQL API has subscription source and the user
             does NOT pay through Apple, we need to direct them to manage
             their subscription else where.

             if userInfo.subscription.source != .apple {
                 if userInfo.subscriptionType != .lifetime {
                     return Text("Please sign in to Neeva from your computer to manage your membership.")
                 else {
                     return EmptyView()
                 }
             } else {
                 return EmptyView()
             }
             */

            return EmptyView()
        default:
            return EmptyView()
        }
    }

    @ViewBuilder
    private var membershipStatusBody: some View {
        switch userInfo.subscriptionType {
        case .basic:
            VStack(alignment: .leading) {
                Text(SubscriptionType.basic.displayName)
                    .withFont(.headingMedium)
                    .padding(4)
                    .padding(.horizontal, 4)
                    .foregroundColor(.brand.charcoal)
                    .background(SubscriptionType.basic.color)
                    .cornerRadius(4)

                Text(
                    "Neeva’s Free Basic membership gives you access to all Neeva search and personalization features."
                )
                .withFont(.bodyLarge)
                .fixedSize(horizontal: false, vertical: true)
            }
        case .premium, .lifetime:
            VStack(alignment: .leading) {
                Text(SubscriptionType.premium.displayName)
                    .withFont(.headingMedium)
                    .padding(4)
                    .padding(.horizontal, 4)
                    .foregroundColor(.brand.charcoal)
                    .background(SubscriptionType.premium.color)
                    .cornerRadius(4)

                if userInfo.subscriptionType == .lifetime {
                    Text(
                        "As a winner in Neeva's referral competition, you are a lifetime Premium member of Neeva."
                    )
                    .withFont(.bodyLarge)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Text(
                    "If you have any questions or need assistance with your Premium membership, please reach out to premium@neeva.co."
                )
                .withFont(.bodyLarge)
                .fixedSize(horizontal: false, vertical: true)
            }

            NavigationLinkButton("View Benefits") {
                openURL(NeevaConstants.appMembershipURL)
            }
        default:
            VStack {
                Button("Learn More on the Neeva Website") {
                    openURL(NeevaConstants.appMembershipURL)
                }
            }
        }
    }
}

struct NeevaAccountInfoView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(SSOProvider.allCases, id: \.self) { authProvider in
            NeevaAccountInfoView(
                isPresented: .constant(true),
                userInfo: NeevaUserInfo(
                    previewDisplayName: "First Last", email: "name@example.com",
                    pictureUrl:
                        "https://pbs.twimg.com/profile_images/1273823608297500672/MBtG7NMI_400x400.jpg",
                    authProvider: authProvider))
        }.previewLayout(.fixed(width: 375, height: 150))
    }
}
