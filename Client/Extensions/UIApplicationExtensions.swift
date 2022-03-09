// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import Shared

public enum OpenSysSettingTrigger: String {
    case defaultBrowserPrompt
    case defaultBrowserPromoCard
    case defaultBrowserPromptDirect
    case settings
    case defaultBrowserPromptMergeEduction
}

extension UIApplication {

    func openSettings(triggerFrom: OpenSysSettingTrigger) {
        ClientLogger.shared.logCounter(
            .GoToSysAppSettings,
            attributes: [
                ClientLogCounterAttribute(
                    key: LogConfig.UIInteractionAttribute.openSysSettingTriggerFrom,
                    value: triggerFrom.rawValue
                )
            ]
        )
        self.open(
            URL(string: UIApplication.openSettingsURLString)!, options: [:])
    }
}
