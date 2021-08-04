// Copyright Neeva. All rights reserved.

import Defaults
import Shared
import SwiftUI

class DefaultBrowserOnboardingViewController: UIHostingController<
    DefaultBrowserOnboardingViewController.Content
>
{
    struct Content: View {
        let openSettings: () -> Void
        let onCancel: () -> Void

        var body: some View {
            VStack {
                HStack {
                    Spacer()
                    CloseButton(action: onCancel)
                        .padding(.trailing, 20)
                        .padding(.top)
                        .background(Color.clear)
                }
                DefaultBrowserOnboardingView(openSettings: openSettings)
            }
        }
    }

    init(didOpenSettings: @escaping () -> Void) {
        super.init(rootView: Content(openSettings: {}, onCancel: {}))
        self.rootView = Content(
            openSettings: { [weak self] in
                self?.dismiss(animated: true) {
                    UIApplication.shared.open(
                        URL(string: UIApplication.openSettingsURLString)!, options: [:])
                    didOpenSettings()
                }
                // Don't show default browser card if this button is tapped
                Defaults[.didDismissDefaultBrowserCard] = true
            },
            onCancel: { [weak self] in
                self?.dismiss(animated: true, completion: nil)
            }
        )
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct DefaultBrowserOnboardingView: View {
    let openSettings: () -> Void

    var body: some View {
        VStack {
            Spacer()

            Text(String.DefaultBrowserCardTitle)
                .withFont(.displayMedium)
                .multilineTextAlignment(.center)
                .padding(.bottom)

            Text(
                [
                    String.DefaultBrowserCardDescription,
                    String.DefaultBrowserOnboardingDescriptionStep1,
                    String.DefaultBrowserOnboardingDescriptionStep2,
                    String.DefaultBrowserOnboardingDescriptionStep3,
                ].joined(separator: "\n\n")
            )
            .withFont(.bodyXLarge)

            Spacer().repeated(3)

            ZStack {
                Image("Default Browser Setting Screenshot")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 350, height: 200)
                    .clipped()  // otherwise the image background blocks the close button
                    .overlay(
                        Text(String.DefaultBrowserOnboardingScreenshot)
                            .font(.system(size: 18))
                            .offset(x: 20, y: 122),
                        alignment: .topLeading
                    )
            }

            Spacer().repeated(3)

            Button(action: openSettings) {
                HStack {
                    Spacer()
                    Text("Go to Settings")
                        .withFont(.labelLarge)
                    Spacer()
                }
            }
            .buttonStyle(BigBlueButtonStyle())
            .font(.title3)
        }
        .padding(25)
        .navigationTitle("Default Browser")
    }
}

struct DefaultBrowserOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DefaultBrowserOnboardingView(openSettings: {})
                .navigationBarTitleDisplayMode(.inline)
        }

        DefaultBrowserOnboardingViewController.Content(openSettings: {}, onCancel: {})
    }
}
