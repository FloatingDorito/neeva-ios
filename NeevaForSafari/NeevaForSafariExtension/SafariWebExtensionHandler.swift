// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SafariServices
import os.log

private enum ExtensionRequests: String {
    case SavePreference = "savePreference"
    case GetPreference = "getPreference"
}

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    private let defaults = UserDefaults.standard

    func beginRequest(with context: NSExtensionContext) {
        let item = context.inputItems[0] as! NSExtensionItem
        let data = item.userInfo?["message"] as? [String: Any]

        if let savePreference = data?[ExtensionRequests.SavePreference.rawValue] as? String, let value = data?["value"] as? Bool {
            os_log(.default, "Saving user preference %{private}@ (NEEVA FOR SAFARI)", savePreference)
            defaults.set(value, forKey: savePreference)
        } else if let getPreference = data?[ExtensionRequests.GetPreference.rawValue] as? String {
            os_log(.default, "Retrieving user preference %{private}@ (NEEVA FOR SAFARI)", getPreference)

            let response = NSExtensionItem()
            response.userInfo = [ SFExtensionMessageKey: ["value":  defaults.bool(forKey: getPreference)]]
            context.completeRequest(returningItems: [response]) { _ in
                os_log(.default, "Returned data to extension %{private}@ (NEEVA FOR SAFARI)", response.userInfo!)
            }
        } else {
            os_log(.default, "Received request with no usable instructions (NEEVA FOR SAFARI)")
        }
    }
}
