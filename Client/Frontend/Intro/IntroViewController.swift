/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import AuthenticationServices
import Defaults
import Foundation
import Shared
import SnapKit
import UIKit

enum FirstRunButtonActions {
    case signin
    case signupWithApple(Bool?, String?)
    case signupWithOther
    case skipToBrowser
    case oktaSignup(String, String, String, Bool)  //email, first name, password, marketing option
    case oktaSignin(String)  // email
    case oauthWithProvider(NeevaConstants.OAuthProvider, Bool, String, String)
    case oktaAccountCreated(String)  // token
}

class IntroViewController: UIViewController {

    private lazy var welcomeCard = UIView()
    private var marketingEmailOptOut: Bool = true
    private var signInMode: Bool
    private var onOtherOptionsPage: Bool

    // Closure delegate
    var didFinishClosure: ((FirstRunButtonActions) -> Void)?

    // MARK: Initializer
    init(
        signInMode: Bool = false, onOtherOptionsPage: Bool = false,
        marketingEmailOptOut: Bool = true
    ) {
        self.signInMode = signInMode
        self.onOtherOptionsPage = onOtherOptionsPage
        self.marketingEmailOptOut = marketingEmailOptOut
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        initialViewSetup()
    }

    // MARK: View setup
    private func initialViewSetup() {
        setupIntroView()
    }

    private func setupWelcomeCard() {
        // Constraints
        welcomeCard.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func buttonAction(_ option: FirstRunButtonActions) {
        // Make sure all actions are run on the main thread to prevent runtime errors
        DispatchQueue.main.async {
            switch option {
            case FirstRunButtonActions.signupWithApple(let marketingEmailOptOut, _):
                if !Defaults[.introSeen] {
                    Defaults[.firstRunPath] = "FirstRunSignupWithApple"
                }
                self.marketingEmailOptOut = marketingEmailOptOut ?? false
                self.doSignupWithApple()
            case FirstRunButtonActions.signin:
                break
            case .signupWithOther:
                break
            case FirstRunButtonActions.skipToBrowser:
                if !Defaults[.introSeen] {
                    Defaults[.firstRunPath] = "FirstRunSkipToBrowser"
                }
                self.didFinishClosure?(.skipToBrowser)
            case FirstRunButtonActions.oktaSignup(
                let email,
                let firstname,
                let password,
                let marketingEmailOptOut
            ):
                self.createOktaAccount(
                    email: email,
                    firstname: firstname,
                    password: password,
                    marketingEmailOptOut: marketingEmailOptOut
                )
                break
            case FirstRunButtonActions.oktaSignin(let email):
                self.didFinishClosure?(.oktaSignin(email))
                break
            case FirstRunButtonActions.oauthWithProvider(
                let provider, let marketingEmailOptOut, _, let email):
                self.marketingEmailOptOut = marketingEmailOptOut
                self.oauthWithProvider(provider: provider, email: email)
                break
            case FirstRunButtonActions.oktaAccountCreated(_):
                break
            }
        }
    }

    //onboarding intro view
    private func setupIntroView() {
        // Initialize
        view.addSubview(welcomeCard)
        welcomeCard.snp.makeConstraints { make in
            make.top.left.right.bottom.equalTo(self.view)
        }
        addSubSwiftUIView(
            IntroFirstRunView(
                buttonAction: buttonAction, signInMode: self.signInMode,
                onOtherOptionsPage: onOtherOptionsPage),
            to: welcomeCard)
        setupWelcomeCard()
    }

    private func doSignupWithApple() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    private func oauthWithProvider(provider: NeevaConstants.OAuthProvider, email: String) {
        guard
            let authURL = provider == .okta
                ? URL(
                    string: NeevaConstants.signupOAuthString(
                        provider: provider,
                        mktEmailOptOut: self.marketingEmailOptOut,
                        email: email))
                : URL(
                    string: NeevaConstants.signupOAuthString(
                        provider: provider,
                        mktEmailOptOut: self.marketingEmailOptOut))
        else { return }

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: NeevaConstants.neevaOAuthCallbackScheme()
        ) { [self] callbackURL, error in

            if error != nil {
                Logger.browser.error(
                    "ASWebAuthenticationSession OAuth failed: \(String(describing: error))")
            }

            guard error == nil, let callbackURL = callbackURL else { return }
            let queryItems = URLComponents(string: callbackURL.absoluteString)?.queryItems
            let token = queryItems?.filter({ $0.name == "sessionKey" }).first?.value
            let serverErrorCode = queryItems?.filter({ $0.name == "retry" }).first?.value

            if let errorCode = serverErrorCode {
                var errorMessage = "Some unknown error occurred"

                switch errorCode {
                case "NL003":
                    errorMessage =
                        "There is already an account for this email address. Please sign in with Google instead."
                    break
                case "NL004":
                    errorMessage =
                        "There is already an account for this email address. Please sign in with Apple instead."
                    break
                case "NL005":
                    errorMessage =
                        "There is already an account for this email address. Please sign in with Microsoft instead."
                    break
                case "NL013":
                    errorMessage =
                        "There is already an account for this email address. Please sign in with your email address instead."
                    break
                case "NL002":
                    errorMessage = "There is already an account for this email address."
                    break
                default:
                    break
                }
                showErrorAlert(errMsg: errorMessage)
            } else if let cookie = token {
                self.didFinishClosure?(
                    .oauthWithProvider(provider, self.marketingEmailOptOut, cookie, email))
            }
        }

        session.presentationContextProvider = self
        session.start()
    }

    func showErrorAlert(errMsg: String) {
        let alert = UIAlertController(title: "Error", message: errMsg, preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(
                title: NSLocalizedString("OK", comment: "Default action"),
                style: .default,
                handler: { _ in
                    Logger.browser.error(
                        "Showed error alert message: \(String(describing: errMsg))")
                }
            )
        )
        self.present(alert, animated: true, completion: nil)
    }
}

extension IntroViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return self.view.window!
    }
}

extension IntroViewController: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        switch authorization.credential {
        case let appleIDCredential as ASAuthorizationAppleIDCredential:
            // redirect and create account
            let token = appleIDCredential.identityToken

            if token != nil {
                if let authStr = String(data: token!, encoding: .utf8) {

                    self.didFinishClosure?(.signupWithApple(self.marketingEmailOptOut, authStr))
                }
            }
            break
        default:
            break
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Logger.browser.error("Sign up with Apple failed: \(error)")
    }
}

extension IntroViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
}

// MARK: UIViewController setup
extension IntroViewController {
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var shouldAutorotate: Bool {
        return false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // This actually does the right thing on iPad where the modally
        // presented version happily rotates with the iPad orientation.
        return .portrait
    }
}
