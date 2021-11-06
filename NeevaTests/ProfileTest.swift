/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared
import Storage
import SwiftKeychainWrapper
import XCTest

@testable import Neeva

/*
 * A base test type for tests that need a profile.
 */

class ProfileTest: XCTestCase {

    var profile: MockProfile?

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        // Setup mock profile
        profile = MockProfile(databasePrefix: "profile-test")
    }

    func withTestProfile(_ callback: (_ profile: Neeva.Profile) -> Void) {
        guard let mockProfile = profile else {
            return
        }
        mockProfile._reopen()
        callback(mockProfile)
        mockProfile._shutdown()
    }
}
