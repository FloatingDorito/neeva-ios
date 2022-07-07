// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import StoreKit
import SwiftUI

@available(iOS 15.0, *)
struct NeevaPremium: View {
    let productIdentifiers = ["annual202206", "monthly202206"]
    @State private var products = [Product]()

    var body: some View {
        VStack {
            Text("Hello Premium!")
            List(products) { product in
                Button("\(product.displayName)") {
                    Task {
                        // If you see the warning "Making a purchase without listening
                        // for transaction updates risks missing successful purchases."...
                        // we have server side webhooks that will update the users profile
                        // so the next time it is refreshed, premium content will
                        // automatically be unlocked.
                        let result = try await product.purchase()

                        switch result {
                        case .success(let verificationResult):
                            switch verificationResult {
                            case .verified(let transaction):
                                // TODO: call our API and bump premium (fallback for a webhook delay)
                                // TODO: then refresh user profile info
                                // TODO: log
                                print("*** verified")
                                await transaction.finish()
                            case .unverified(let transaction, let verificationError):
                                // if we got here StoreKitV2 was unable to verify the JWT token, probably a very rare event
                                // TODO: what should we do in this case? maybe the answer is nothing.
                                // TODO: log
                                print("*** unverified")
                                print("*** transaction: \(transaction)")
                                print("*** error: \(verificationError)")
                            }
                        case .pending:
                            // The purchase requires action from the customer.
                            // If the transaction completes, it's available through Transaction.updates.
                            // TODO: what should we do in this case? maybe the answer is nothing.
                            // TODO: log
                            print("*** pending")
                            break
                        case .userCancelled:
                            // The user canceled the purchase.
                            // TODO: log
                            print("*** cancelled")
                            break
                        @unknown default:
                            break
                        }
                    }
                }
            }
        }
        .navigationTitle("Premium")
        .task {
            // load products
            do {
                products = try await Product.products(for: productIdentifiers)
            } catch {
                // do nothing
            }
        }
    }
}
