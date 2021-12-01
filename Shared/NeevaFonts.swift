// Copyright Neeva. All rights reserved.

import SwiftUI

public enum FontStyle {
    case displayXLarge, displayLarge, displayMedium

    case headingXLarge, headingLarge, headingMedium, headingSmall
    /// too small for normal UI, use it sparingly.
    case headingXSmall

    case bodyXLarge, bodyLarge, bodyMedium, bodySmall, bodyXSmall

    case labelLarge, labelMedium, labelSmall
}

extension View {
    /// Note: this overload does not include kerning
    public func withFont(unkerned style: FontStyle, weight: UIFont.Weight? = nil) -> some View {
        modifier(FontStyleModifier(style: style, weight: weight))
    }
}

extension Image {
    // removes the `unkerned` reminder since kerning is irrelevant for SF Symbols
    public func withFont(_ style: FontStyle, weight: UIFont.Weight? = nil) -> some View {
        modifier(FontStyleModifier(style: style, weight: weight))
    }
}

extension Text {
    public typealias WithFont = ModifiedContent<Kern, Shared.FontStyleModifier>
    public func withFont(_ style: FontStyle, weight: UIFont.Weight? = nil) -> WithFont {
        Kern(style: style, content: self)
            .modifier(FontStyleModifier(style: style, weight: weight))
    }
}

public struct Kern: View {
    let style: FontStyle
    let content: Text
    @Environment(\.sizeCategory) private var sizeCategory
    public var body: some View {
        content.kerning(style.kerning(at: style.size(in: sizeCategory)))
    }
}

public struct FontStyleModifier: ViewModifier {
    fileprivate let style: FontStyle
    fileprivate let weight: UIFont.Weight?

    @Environment(\.sizeCategory) private var sizeCategory
    public func body(content: Content) -> some View {
        let font = style.uiFont(for: sizeCategory)
        let lineHeight = (style.lineHeightMultiplier * font.pointSize)
            .rounded(.toNearestOrAwayFromZero)
        content
            .font(Font(font))
            .lineSpacing(lineHeight - font.lineHeight)
            .padding(.vertical, (lineHeight - font.lineHeight) / 2)
            .textCase(style.textCase)
    }
}

extension FontStyle {
    var lineHeightMultiplier: CGFloat {
        switch self {
        case .displayXLarge, .displayLarge, .displayMedium:
            return 1.25

        case .headingXLarge: return 1.4
        case .headingLarge: return 1.35
        case .headingMedium: return 1.4
        case .headingSmall, .headingXSmall: return 1.5

        case .bodyXLarge: return 1.35
        case .bodyLarge, .bodyMedium: return 1.4
        case .bodySmall, .bodyXSmall: return 1.5

        case .labelLarge, .labelMedium: return 1.4
        case .labelSmall: return 1.5
        }
    }

    func kerning(at size: CGFloat) -> CGFloat {
        switch self {
        case .displayXLarge, .displayLarge, .displayMedium:
            return 0.5

        case .headingXLarge:
            return 0.02 * size
        case .headingLarge, .headingMedium, .headingSmall:
            return 0
        case .headingXSmall:
            return 0.05 * size

        case .bodyXLarge, .bodyLarge, .bodyMedium, .bodySmall, .bodyXSmall:
            return 0

        case .labelLarge, .labelMedium:
            return 0
        case .labelSmall:
            return 0.1 * size
        }
    }

    var fontWeight: UIFont.Weight {
        switch self {
        case .displayXLarge, .displayLarge: return .light
        case .displayMedium: return .medium

        case .headingXLarge: return .semibold
        case .headingLarge: return .regular
        case .headingMedium: return .semibold
        case .headingSmall: return .medium
        case .headingXSmall: return .regular

        case .bodyXLarge, .bodyLarge, .bodyMedium, .bodySmall, .bodyXSmall: return .regular

        case .labelLarge: return .semibold
        case .labelMedium, .labelSmall: return .medium
        }
    }

    var textCase: Text.Case? {
        switch self {
        case .headingXSmall, .labelSmall: return .uppercase
        default: return nil
        }
    }

    public func uiFont(for category: ContentSizeCategory, weight: UIFont.Weight? = nil) -> UIFont {
        return UIFont.systemFont(ofSize: size(in: category), weight: weight ?? fontWeight)
    }

    private static func defaultSize(for style: UIFont.TextStyle, in category: ContentSizeCategory)
        -> CGFloat
    {
        UIFontDescriptor.preferredFontDescriptor(
            withTextStyle: style,
            compatibleWith: UITraitCollection(
                preferredContentSizeCategory: UIContentSizeCategory(category))
        ).pointSize
    }

    func size(in category: ContentSizeCategory) -> CGFloat {
        switch self {
        // MARK: Display
        case .displayXLarge:
            switch category {
            case .extraSmall: return 45
            case .small: return 46
            case .medium: return 47
            case .large: return 48
            case .extraLarge: return 50
            case .extraExtraLarge: return 52
            case .extraExtraExtraLarge: return 54
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                return Self.defaultSize(for: .largeTitle, in: category)
            @unknown default: return size(in: .large)
            }
        case .displayLarge:
            switch category {
            case .extraSmall: return 37
            case .small: return 38
            case .medium: return 39
            case .large: return 40
            case .extraLarge: return 42
            case .extraExtraLarge: return 44
            case .extraExtraExtraLarge: return 46
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                return Self.defaultSize(for: .largeTitle, in: category)
            @unknown default: return size(in: .large)
            }
        case .displayMedium:
            switch category {
            case .extraSmall: return 21
            case .small: return 22
            case .medium: return 23
            case .large: return 24
            case .extraLarge: return 26
            case .extraExtraLarge: return 28
            case .extraExtraExtraLarge: return 30
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                return Self.defaultSize(for: .title1, in: category)
            @unknown default: return size(in: .large)
            }

        // MARK: Heading
        case .headingXLarge:
            switch category {
            case .extraSmall: return 17
            case .small: return 18
            case .medium: return 19
            case .large: return 20
            case .extraLarge: return 22
            case .extraExtraLarge: return 24
            case .extraExtraExtraLarge: return 26
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                return Self.defaultSize(for: .title1, in: category)
            @unknown default: return size(in: .large)
            }
        case .headingLarge:
            switch category {
            case .extraSmall: return 15
            case .small: return 16
            case .medium: return 17
            case .large: return 18
            case .extraLarge: return 20
            case .extraExtraLarge: return 22
            case .extraExtraExtraLarge: return 24
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                return Self.defaultSize(for: .title2, in: category)
            @unknown default: return size(in: .large)
            }
        case .headingMedium:
            switch category {
            case .extraSmall: return 13
            case .small: return 14
            case .medium: return 15
            case .large: return 16
            case .extraLarge: return 18
            case .extraExtraLarge: return 20
            case .extraExtraExtraLarge: return 22
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                return Self.defaultSize(for: .title3, in: category)
            @unknown default: return size(in: .large)
            }
        case .headingSmall:
            switch category {
            case .extraSmall: return 11
            case .small: return 12
            case .medium: return 12
            case .large: return 13
            case .extraLarge: return 15
            case .extraExtraLarge: return 17
            case .extraExtraExtraLarge: return 19
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                return Self.defaultSize(for: .headline, in: category)
            @unknown default: return size(in: .large)
            }
        case .headingXSmall:
            switch category {
            case .extraSmall: return 10
            case .small: return 10
            case .medium: return 10
            case .large: return 10
            case .extraLarge: return 12
            case .extraExtraLarge: return 14
            case .extraExtraExtraLarge: return 16
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                return Self.defaultSize(for: .subheadline, in: category)
            @unknown default: return size(in: .large)
            }

        // MARK: Body
        case .bodyXLarge:
            switch category {
            case .extraSmall: return 15
            case .small: return 16
            case .medium: return 17
            case .large: return 18
            case .extraLarge: return 20
            case .extraExtraLarge: return 22
            case .extraExtraExtraLarge: return 24
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                return Self.defaultSize(for: .title3, in: category)
            @unknown default: return size(in: .large)
            }
        case .bodyLarge:
            switch category {
            case .extraSmall: return 13
            case .small: return 14
            case .medium: return 15
            case .large: return 16
            case .extraLarge: return 18
            case .extraExtraLarge: return 20
            case .extraExtraExtraLarge: return 22
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                return Self.defaultSize(for: .headline, in: category)
            @unknown default: return size(in: .large)
            }
        case .bodyMedium:
            switch category {
            case .extraSmall: return 11
            case .small: return 12
            case .medium: return 13
            case .large: return 14
            case .extraLarge: return 16
            case .extraExtraLarge: return 18
            case .extraExtraExtraLarge: return 20
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                return Self.defaultSize(for: .body, in: category)
            @unknown default: return size(in: .large)
            }
        case .bodySmall:
            switch category {
            case .extraSmall: return 11
            case .small: return 12
            case .medium: return 12
            case .large: return 13
            case .extraLarge: return 15
            case .extraExtraLarge: return 17
            case .extraExtraExtraLarge: return 29
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                return Self.defaultSize(for: .body, in: category)
            @unknown default: return size(in: .large)
            }
        case .bodyXSmall:
            switch category {
            case .extraSmall: return 11
            case .small: return 11
            case .medium: return 11
            case .large: return 12
            case .extraLarge: return 14
            case .extraExtraLarge: return 16
            case .extraExtraExtraLarge: return 18
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                return Self.defaultSize(for: .footnote, in: category)
            @unknown default: return size(in: .large)
            }

        // MARK: Label
        case .labelLarge:
            switch category {
            case .extraSmall: return 13
            case .small: return 14
            case .medium: return 15
            case .large: return 16
            case .extraLarge: return 18
            case .extraExtraLarge: return 20
            case .extraExtraExtraLarge: return 22
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                return Self.defaultSize(for: .headline, in: category)
            @unknown default: return size(in: .large)
            }
        case .labelMedium:
            switch category {
            case .extraSmall: return 11
            case .small: return 12
            case .medium: return 13
            case .large: return 14
            case .extraLarge: return 16
            case .extraExtraLarge: return 18
            case .extraExtraExtraLarge: return 20
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                return Self.defaultSize(for: .body, in: category)
            @unknown default: return size(in: .large)
            }
        case .labelSmall:
            switch category {
            case .extraSmall: return 11
            case .small: return 11
            case .medium: return 11
            case .large: return 12
            case .extraLarge: return 14
            case .extraExtraLarge: return 16
            case .extraExtraExtraLarge: return 18
            case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
                return Self.defaultSize(for: .footnote, in: category)
            @unknown default: return size(in: .large)
            }

        }
    }
}
