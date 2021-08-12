/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import SDWebImage
import Shared
import Storage
import UIKit

extension UIColor {
    var components: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
}

extension UIImageView {

    public func setImageAndBackground(
        forIcon icon: Favicon?, website: URL?,
        defaultBackground: UIColor = .init(light: .white, dark: .clear),
        completion: @escaping () -> Void
    ) {
        func finish(bgColor: UIColor?) {
            if let bgColor = bgColor {
                // If the background color is clear, we may decide to set our own background based on the theme.
                let color = bgColor.components.alpha < 0.01 ? defaultBackground : bgColor
                self.backgroundColor = color
            }
            completion()
        }

        backgroundColor = nil
        sd_setImage(with: nil)  // cancels any pending SDWebImage operations.

        if let url = website, let bundledIcon = FaviconFetcher.getBundledIcon(forUrl: url) {
            print(">>> using bundled icon for \(url.host ?? "")")
            self.image = UIImage(contentsOfFile: bundledIcon.filePath)
            finish(bgColor: bundledIcon.bgcolor)
        } else if let image = FaviconFetcher.getFaviconFromDiskCache(
            imageKey: website?.baseDomain ?? "")
        {
            print(">>> using cached icon for \(website?.host ?? "")")
            self.image = image
            finish(bgColor: .systemBackground)
        } else {
            let defaults = fallbackFavicon(forUrl: website)
            self.sd_setImage(with: icon?.url, placeholderImage: defaults.image, options: []) {
                (img, err, _, _) in
                guard err == nil else {
                    finish(bgColor: defaults.color)
                    return
                }
                finish(bgColor: nil)
            }
        }
    }

    public func setFavicon(forSite site: Site, completion: @escaping () -> Void) {
        setImageAndBackground(forIcon: site.icon, website: site.tileURL, completion: completion)
    }

    private func fallbackFavicon(forUrl url: URL?) -> (image: UIImage, color: UIColor) {
        if let url = url {
            print(">>> using letter icon for \(url.host ?? "")")
            return FaviconFetcher.letter(forUrl: url)
        } else {
            print(">>> using default icon for unknown")
            return (FaviconFetcher.defaultFavicon, .clear)
        }
    }

    public func setImageColor(color: UIColor) {
        let templateImage = self.image?.withRenderingMode(.alwaysTemplate)
        self.image = templateImage
        self.tintColor = color
    }
}
