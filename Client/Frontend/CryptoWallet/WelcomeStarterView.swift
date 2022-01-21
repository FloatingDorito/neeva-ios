// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Defaults
import Shared
import SwiftUI
import web3swift

struct WelcomeStarterView: View {
    @EnvironmentObject var web3Model: Web3Model
    @State var isCreatingWallet: Bool = false
    @Binding var viewState: ViewState

    var body: some View {
        VStack {
            VStack {
                Text("Welcome to Neeva")
                Text("Crypto Wallet")
            }
            .font(.roobert(size: 28))
            .padding(.top, 10)
            .padding(.bottom, 20)

            VStack {
                Text("Let's get set up!")
                    .font(.roobert(size: 22))
                    .frame(width: 300, height: 50, alignment: .leading)
                Button(action: {
                    isCreatingWallet = true
                    web3Model.createWallet {
                        isCreatingWallet = false
                        viewState = .showPhrases
                    }
                }) {
                    HStack {
                        Text(isCreatingWallet ? "Creating " : "Create a wallet")
                            .font(.roobert(.semibold, size: 18))
                        if isCreatingWallet {
                            ProgressView()
                        }
                    }.frame(maxWidth: .infinity)

                }
                .buttonStyle(.neeva(.primary))
                .padding(.vertical)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10).stroke(Color.ui.gray91, lineWidth: 0.5)
            )
            .background(Color.white.opacity(0.8))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 15)

            VStack {
                VStack(alignment: .leading) {
                    Text("I already have a Secret")
                    Text("Recovery Phrase")
                }
                .font(.roobert(size: 22))
                .frame(width: 300, height: 60, alignment: .leading)

                Text(
                    "If you are not sure what is a Secret Recovery Phrase, click Create a wallet on the top"
                )
                .font(.system(size: 14))
                .multilineTextAlignment(.leading)
                .foregroundColor(.secondary)

                Button(action: { viewState = .importWallet }) {
                    Text("Import wallet")
                        .font(.roobert(.semibold, size: 18))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.neeva(.primary))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10).stroke(Color.ui.gray91, lineWidth: 0.5)
            )
            .background(Color.white.opacity(0.8))
            .cornerRadius(10)
            .padding(.horizontal, 16)
        }
    }
}
