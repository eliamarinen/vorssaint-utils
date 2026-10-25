// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Shared content bounds for ordinary Settings pages.
enum SettingsPageLayout {
    static let contentWidth: CGFloat = 760
    static let margin: CGFloat = 22
}

/// Context stays in the content; the destination's title belongs to the toolbar.
struct SettingsPageDescription: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    /// Apply inside a scroll view; forms use `settingsFormFrame` instead.
    func settingsPageFrame() -> some View {
        frame(maxWidth: SettingsPageLayout.contentWidth)
            .frame(maxWidth: .infinity)
            .padding(SettingsPageLayout.margin)
    }

    /// A form owns its scrolling viewport. Inset only its content, leaving the
    /// scroll indicators and native scroll-edge effects at the pane's edges.
    func settingsFormFrame() -> some View {
        GeometryReader { geometry in
            self
                .contentMargins(.horizontal,
                    max(SettingsPageLayout.margin,
                        (geometry.size.width - SettingsPageLayout.contentWidth) / 2),
                    for: .scrollContent)
                .contentMargins(.vertical, SettingsPageLayout.margin, for: .scrollContent)
        }
    }

    /// The shared column without the outer margin, for a pinned strip that
    /// already draws its own horizontal padding.
    func settingsPageWidth() -> some View {
        frame(maxWidth: SettingsPageLayout.contentWidth)
            .frame(maxWidth: .infinity)
    }
}
