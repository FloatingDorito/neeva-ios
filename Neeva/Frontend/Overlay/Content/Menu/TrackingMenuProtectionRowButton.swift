// Copyright Neeva. All rights reserved.

import Defaults
import Shared
import SwiftUI

public struct TrackingMenuProtectionRowButton: View {

    @Binding var preventTrackers: Bool

    public var body: some View {
        GroupedCell {
            Toggle(isOn: $preventTrackers) {
                VStack(alignment: .leading) {
                    Text("Tracking Prevention")
                        .withFont(.bodyLarge)
                    Text("Website not working? Try disabling")
                        .foregroundColor(.secondaryLabel)
                        .font(.footnote)
                }
            }
            .accessibilityIdentifier("TrackingMenu.TrackingMenuProtectionRow")
            .padding(.vertical, 12)
            .applyToggleStyle()
        }
    }
}

struct TrackingMenuProtectionRowButton_Previews: PreviewProvider {
    static var previews: some View {
        TrackingMenuProtectionRowButton(preventTrackers: .constant(true))
        TrackingMenuProtectionRowButton(preventTrackers: .constant(false))
    }
}
