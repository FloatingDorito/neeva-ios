// Copyright Neeva. All rights reserved.

import Shared
import SwiftUI
import WebKit

struct AboutSettingsSection: View {
    @Binding var showDebugSettings: Bool
    @Environment(\.onOpenURL) var openURL
    var body: some View {
        Menu {
            Button(action: {
                UIPasteboard.general.string = "Neeva Browser \(AppInfo.appVersion) (\(AppInfo.buildNumber))"
            }) {
                Label("Copy Version information", systemSymbol: .docOnDoc)
            }
            Button(action: { showDebugSettings.toggle() }) {
                Label(
                    String("Toggle Debug Settings"),
                    systemSymbol: showDebugSettings ? .checkmarkSquare : .square)
            }
        } label: {
            HStack {
                Text("Neeva Browser \(AppInfo.appVersion) (\(AppInfo.buildNumber))")
                Spacer()
            }.padding(.vertical, 3).contentShape(Rectangle())
        }.accentColor(.label)

        makeNavigationLink(title: "Licenses") {
            LicensesView()
                .ignoresSafeArea(.all, edges: [.bottom, .horizontal])
        }

        NavigationLinkButton("Terms") {
            ClientLogger.shared.logCounter(
                .ViewTerms, attributes: EnvironmentHelper.shared.getAttributes())
            openURL(NeevaConstants.appTermsURL)
        }
    }
}

struct LicensesView: UIViewRepresentable {
    func makeUIView(context: Context) -> some UIView {
        let config = TabManager.makeWebViewConfig(isPrivate: true)
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(
            frame: CGRect(width: 1, height: 1),
            configuration: config
        )
        webView.allowsLinkPreview = false

        // This is not shown full-screen, use mobile UA
        webView.customUserAgent = UserAgent.mobileUserAgent()

        ClientLogger.shared.logCounter(
            .ViewLicenses, attributes: EnvironmentHelper.shared.getAttributes())

        if let url = URL(string: "\(InternalURL.baseUrl)/\(AboutLicenseHandler.path)") {
            webView.load(PrivilegedRequest(url: url) as URLRequest)
        }

        return webView
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {}
}

struct AboutSettingsSection_Previews: PreviewProvider {
    private struct Preview: View {
        @State var showDebugSettings = false
        var body: some View {
            AboutSettingsSection(showDebugSettings: $showDebugSettings)
        }
    }
    static var previews: some View {
        SettingPreviewWrapper {
            Section(header: Text("About")) {
                Preview()
            }
            Section(header: Text("About — Debug enabled")) {
                Preview(showDebugSettings: true)
            }
        }
    }
}
