// Copyright Neeva. All rights reserved.

import Defaults
import SwiftUI
import web3swift

struct WelcomeStarterView: View {
    @Binding var isCreatingWallet: Bool

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
                Text(isCreatingWallet ? "Creating your wallet" : "Let's get set up!")
                    .font(.roobert(size: 22))
                    .frame(width: 300, height: 50, alignment: .leading)
                Button(action: { isCreatingWallet = true }) {
                    Text(isCreatingWallet ? "Creating ... " : "Create a wallet")
                        .font(.roobert(.semibold, size: 18))
                }
                .frame(minWidth: 300, minHeight: 50)
                .foregroundColor(Color.brand.white)
                .background(Color.brand.blue)
                .cornerRadius(15)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 10).stroke(Color.ui.gray91, lineWidth: 0.5)
            )
            .background(Color.white.opacity(0.8))
            .padding(.bottom, 15)

            VStack {
                VStack(alignment: .leading) {
                    Text("I already have a Secret")
                    Text("Recovery Phrase")
                }
                .font(.roobert(size: 22))
                .frame(width: 300, height: 60, alignment: .leading)

                Text("If you are not sure what is a Secret Recovery Phrase, click Create a wallet on the top")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)

                Button(action: {}) {
                    Text("Import wallet")
                        .font(.roobert(.semibold, size: 18))
                }
                .frame(minWidth: 300, minHeight: 50)
                .foregroundColor(Color.brand.white)
                .background(Color.brand.blue)
                .cornerRadius(15)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 10).stroke(Color.ui.gray91, lineWidth: 0.5)
            )
            .background(Color.white.opacity(0.8))
        }
    }
}
