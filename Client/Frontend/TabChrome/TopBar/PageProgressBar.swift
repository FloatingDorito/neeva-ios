// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI

struct PageProgressBarStyle: ProgressViewStyle {
    fileprivate init() {}
    func makeBody(configuration: Configuration) -> some View {
        let progress = configuration.fractionCompleted ?? 0
        GeometryReader { geom in
            Color.brand.adaptive.maya
                .frame(width: geom.size.width * CGFloat(progress))
        }
        .frame(height: 2)
    }
}

extension ProgressViewStyle where Self == PageProgressBarStyle {
    static var pageProgressBar: Self { .init() }
}

struct PageProgressBarStyle_Previews: PreviewProvider {
    static var previews: some View {
        let preview = VStack {
            ProgressView()
            ProgressView(value: 0)
            ProgressView(value: 0.25)
            ProgressView(value: 0.5).background(Color.red)
            ProgressView(value: 0.75)
            ProgressView(value: 1)
        }
        .padding()
        .progressViewStyle(.pageProgressBar)
        .previewLayout(.sizeThatFits)

        preview
        preview.preferredColorScheme(.dark)
    }
}
