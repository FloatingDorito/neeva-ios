// Copyright Neeva. All rights reserved.

import Shared
import SwiftUI

private enum NeevaMenuUX {
    static let innerSectionPadding: CGFloat = 8
}

struct NeevaMenuView: View {
    private let noTopPadding: Bool
    private let menuAction: (NeevaMenuAction) -> Void

    @State private var openSpacesPrompt = false
    @State private var openFeedbackPrompt = false
    @State private var openSettingsPrompt = false
    @Environment(\.isIncognito) private var isIncognito

    init(noTopPadding: Bool = false, menuAction: @escaping (NeevaMenuAction) -> Void) {
        self.noTopPadding = noTopPadding
        self.menuAction = menuAction
    }

    var body: some View {
        // TODO: when making significant updates, migrate to OverlayGroupedStack
        VStack(alignment: .leading, spacing: GroupedCellUX.spacing) {
            VStack(spacing: NeevaMenuUX.innerSectionPadding) {
                HStack(spacing: NeevaMenuUX.innerSectionPadding) {
                    NeevaMenuButtonView(label: "Home", nicon: .house) {
                        self.menuAction(.home)
                    }
                    .accessibilityIdentifier("NeevaMenu.Home")
                    .disabled(isIncognito)

                    WithPopover(
                        showPopover: $openSpacesPrompt,
                        popoverSize: CGSize(width: 290, height: 150),
                        content: {
                            NeevaMenuButtonView(label: "Spaces", nicon: .bookmarkOnBookmark) {
                                self.menuAction(.spaces)
                            }
                            .accessibilityIdentifier("NeevaMenu.Spaces")
                            .disabled(isIncognito)
                        },
                        popoverContent: {
                            TourPromptView(
                                title: "Want to be organized?",
                                description:
                                    "Save web pages, images, and videos to a curated Space for easy access later",
                                onClose: onCloseTourPrompt, staticColorMode: true)
                        },
                        staticColorMode: true
                    )
                }

                HStack(spacing: NeevaMenuUX.innerSectionPadding) {
                    WithPopover(
                        showPopover: $openSettingsPrompt,
                        popoverSize: CGSize(width: 290, height: 180),
                        content: {
                            NeevaMenuButtonView(label: "Settings", nicon: .gear) {
                                self.menuAction(.settings)
                            }
                            .accessibilityIdentifier("NeevaMenu.Settings")
                        },
                        popoverContent: {
                            TourPromptView(
                                title: "Want to search personal documents?",
                                description:
                                    "Search information in your email, online files and folders, and calendar!",
                                onClose: onCloseTourPrompt, staticColorMode: true)
                        },
                        staticColorMode: true
                    )

                    WithPopover(
                        showPopover: $openFeedbackPrompt,
                        popoverSize: CGSize(width: 290, height: 120),
                        content: {
                            NeevaMenuButtonView(label: "Support", symbol: .bubbleLeft) {
                                self.menuAction(.feedback)
                            }
                            .accessibilityIdentifier("NeevaMenu.Feedback")
                        },
                        popoverContent: {
                            TourPromptView(
                                title: "Have feedback?",
                                description: "We'd love to hear your thoughts!",
                                onClose: onCloseTourPrompt, staticColorMode: true)
                        },
                        staticColorMode: true
                    )
                }
            }

            GroupedCell.Decoration {
                VStack(spacing: 0) {
                    Color.groupedBackground.frame(height: 1)
                    
                    if NeevaFeatureFlags[.referralPromo] {
                        NeevaMenuRowButtonView(
                            label: "Win $5000 by inviting friends", isPromo: true
                        ) {
                            self.menuAction(.referralPromo)
                        }
                        .accentColor(Color.brand.adaptive.orange)
                        .accessibilityIdentifier("NeevaMenu.ReferralPromo")

                        Color.groupedBackground.frame(height: 1)
                    }

                    NeevaMenuRowButtonView(label: "History", symbol: .clock) {
                        self.menuAction(.history)
                    }
                    .accessibilityIdentifier("NeevaMenu.History")

                    Color.groupedBackground.frame(height: 1)

                    NeevaMenuRowButtonView(label: "Downloads", symbol: .squareAndArrowDown) {
                        ClientLogger.shared.logCounter(
                            .OpenDownloads, attributes: EnvironmentHelper.shared.getAttributes())
                        openDownloadsFolderInFilesApp()
                    }
                    .accessibilityIdentifier("NeevaMenu.Downloads")
                }
            }
        }
        .padding(self.noTopPadding ? [.leading, .trailing] : [.leading, .trailing, .top], 16)
        .padding(.bottom, 12)
        .background(Color.groupedBackground)
        .onAppear(perform: viewDidAppear)
        .onDisappear(perform: viewDidDisappear)
        .accentColor(.label)
    }

    func onCloseTourPrompt() {
        openSpacesPrompt = false
        openFeedbackPrompt = false
        openSettingsPrompt = false

        if TourManager.shared.hasActiveStep() {
            TourManager.shared.responseMessage(
                for: TourManager.shared.getActiveStepName(), exit: true)
        }
    }

    func viewDidAppear() {
        DispatchQueue.main.async {
            updateTourPrompts()
        }
    }

    private func updateTourPrompts() {
        if TourManager.shared.hasActiveStep() {
            switch TourManager.shared.getActiveStepName() {
            case .promptSpaceInNeevaMenu:
                self.openSpacesPrompt.toggle()
            case .promptFeedbackInNeevaMenu:
                self.openFeedbackPrompt.toggle()
            case .promptSettingsInNeevaMenu:
                self.openSettingsPrompt.toggle()
            default:
                break
            }
        }
    }

    private func viewDidDisappear() {
        TourManager.shared.notifyCurrentViewClose()
    }
}

struct NeevaMenuView_Previews: PreviewProvider {
    static var previews: some View {
        NeevaMenuView(menuAction: { _ in }).previewDevice("iPod touch (7th generation)")
            .environment(
                \.sizeCategory, .extraExtraExtraLarge)
        NeevaMenuView(menuAction: { _ in }).environment(\.isIncognito, true)
    }
}
