// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Defaults
import SDWebImageSwiftUI
import SFSafeSymbols
import Shared
import SwiftUI
import UIKit

public enum Web3Theme: String {

    public init(with slug: String?) {
        guard let slug = slug else {
            self = .default
            return
        }
        self = Web3Theme(rawValue: slug) ?? .default
    }

    public static var allCases: [Web3Theme] {
        return [
            .azuki,
            .coolCats,
            .cryptoCoven,
        ]
    }

    case azuki = "azuki"
    case coolCats = "cool-cats-nft"
    case cryptoCoven = "cryptocoven"
    case `default` = ""
}

extension Web3Theme {

    @ViewBuilder
    public var backButton: some View {
        switch self {
        case .azuki, .coolCats, .default:
            Symbol(
                .arrowBackward,
                size: 20,
                weight: .medium,
                label: .TabToolbarBackAccessibilityLabel
            )
        case .cryptoCoven:
            Image(
                uiImage: UIImage(named: "cryptocoven_back")!
                    .withRenderingMode(.alwaysTemplate)
            )
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 22)
            .foregroundColor(.label)
        }
    }

    @ViewBuilder
    public var overflowButton: some View {
        switch self {
        case .azuki, .coolCats, .default:
            Symbol(
                .ellipsisCircle,
                size: 20, weight: .medium,
                label: .TabToolbarMoreAccessibilityLabel)
        case .cryptoCoven:
            Image(
                uiImage:
                    UIImage(named: "cryptocoven_overflow")!
                    .withRenderingMode(.alwaysTemplate)
            )
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 22)
            .foregroundColor(.label)
        }
    }

    @ViewBuilder
    public var walletButton: some View {
        switch self {
        case .default:
            Image("wallet-illustration")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32)
                .accessibilityLabel("Neeva Wallet")
        case .azuki, .cryptoCoven, .coolCats:
            WebImage(url: asset?.imageURL)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(self == .cryptoCoven ? Color.label : Color.white, lineWidth: 2)
                )
                .accessibilityLabel("Neeva Wallet")
        }
    }

    @ViewBuilder
    public var lazyTabButton: some View {
        switch self {
        case .azuki, .coolCats, .default:
            Symbol(
                .plus,
                size: 20,
                weight: .medium,
                label: .TabToolbarBackAccessibilityLabel
            )
        case .cryptoCoven:
            Image(
                uiImage: UIImage(named: "cryptocoven_magnifier")!
                    .withRenderingMode(.alwaysTemplate)
            )
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 22)
            .foregroundColor(.label)
        }
    }

    @ViewBuilder
    public var tabBar: some View {
        if let backgroundImageDestination = backgroundImageDestination {
            HStack {
                Spacer()
                createBackgroundImageView(with: backgroundImageDestination)
                    .opacity(0.2)
            }.background(backgroundColor)
        } else {
            backgroundColor
        }
    }

    @ViewBuilder
    private func createBackgroundImageView(with destination: String) -> some View {
        if self == .azuki {
            WebImage(
                url: URL(string: destination),
                context: [
                    .imageThumbnailPixelSize: CGSize(
                        width: 256,
                        height: 256)
                ]
            )
            .resizable()
            .aspectRatio(contentMode: .fit)
        } else {
            Image(destination)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }

    public var tabsImage: UIImage? {
        switch self {
        case .azuki, .coolCats, .default:
            return Symbol.uiImage(
                .squareOnSquare,
                size: 20,
                weight: .medium
            )
        case .cryptoCoven:
            return UIImage(named: "cryptocoven_tabs")?
                .scalePreservingAspectRatio(
                    targetSize: CGSize(width: 36, height: 36)
                )
                .withRenderingMode(.alwaysTemplate)
        }
    }

    public var backgroundColor: Color {
        switch self {
        case .default:
            return Color.DefaultBackground
        case .azuki:
            return Color(UIColor(named: "azuki_background")!)
        case .cryptoCoven:
            return Color(UIColor(named: "cryptocoven_background")!)
        case .coolCats:
            return Color(UIColor(named: "coolcats_background")!)
        }
    }

    public var backgroundImageDestination: String? {
        switch self {
        case .coolCats:
            return "coolcats_background_image"
        case .azuki:
            return "https://www.azuki.com/map/meta3.png"
        default:
            return nil
        }
    }

    public var asset: Asset? {
        guard
            let asset = AssetStore.shared.assets.first(where: {
                $0.collection?.openSeaSlug == rawValue
            })
        else {
            return nil
        }
        return asset
    }
}

extension UIImage {
    fileprivate func scalePreservingAspectRatio(targetSize: CGSize) -> UIImage {
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height

        let scaleFactor = min(widthRatio, heightRatio)

        let scaledImageSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )

        let renderer = UIGraphicsImageRenderer(
            size: scaledImageSize
        )

        let scaledImage = renderer.image { _ in
            self.draw(
                in: CGRect(
                    origin: .zero,
                    size: scaledImageSize
                ))
        }

        return scaledImage
    }
}
