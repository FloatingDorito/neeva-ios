// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Defaults
import Foundation
import Shared
import SwiftUI
import WalletConnectSwift
import WalletCore
import web3swift

extension Defaults.Keys {
    static func dAppsSession(_ sessionID: String) -> Defaults.Key<Data?> {
        Defaults.Key("DataForSession" + sessionID)
    }
}

protocol WalletConnectPresenter: ModalPresenter {
    @discardableResult func connectWallet(to wcURL: WCURL) -> Bool
}

extension BrowserViewController: WalletConnectPresenter {
    @discardableResult func connectWallet(to wcURL: WCURL) -> Bool {
        #if XYZ
            guard let _ = web3Model.wallet?.ethereumAddress
            else {
                web3Model.showWalletCredentialsPrompt()
                return false
            }

            web3Model.startSequence()
            DispatchQueue.global(qos: .userInitiated).async {
                try? self.web3Model.serverManager?.server.connect(to: wcURL)
            }
            return true
        #else
            return false
        #endif
    }
}

extension BrowserViewController: ToastDelegate {
    func shouldShowToast(for message: LocalizedStringKey) {
        toastViewManager.makeToast(text: message)
    }
}
