// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

enum SettingsShellTests {
    static func run(_ suite: TestSuite) {
        suite.expect(SettingsShellLayout.sidebarWidth(saved: 0) == 260,
                     "an unset sidebar width uses the default")
        suite.expect(SettingsShellLayout.sidebarWidth(saved: 300) == 300,
                     "a chosen sidebar width is restored exactly")
        suite.expect(SettingsShellLayout.sidebarWidth(saved: 100) == 240
                     && SettingsShellLayout.sidebarWidth(saved: 500) == 340,
                     "saved sidebar widths stay inside the resizable range")
        for invalid in [Double.nan, .infinity, -.infinity, -1] {
            suite.expect(SettingsShellLayout.sidebarWidth(saved: invalid) == 260,
                         "an invalid sidebar width falls back to the default")
        }

        let domain = "vorss.tests.settings-shell.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        SettingsShellLayout.storeSidebarWidth(325, defaults: defaults)
        suite.expect(SettingsShellLayout.storedSidebarWidth(defaults: defaults) == 325,
                     "a divider width survives persistence and restoration")

        let pages: [SettingsPage] = [.commandBar, .media, .features, .general, .about]
        let items = pages.map {
            SettingsSearchItem(id: .page($0), destination: FeatureSettingsDestination($0),
                               title: "Localized \($0)", icon: "gearshape")
        }
        let suggestions = SettingsSearchSuggestions.suggestions(items: items,
                                                                    isAvailable: { _ in true })
        suite.expect(suggestions.map(\.id) == [.suggestion(.general), .suggestion(.features),
                                               .suggestion(.media), .suggestion(.commandBar)],
                     "empty search uses the agreed fixed suggestion order, not catalog order")
        suite.expect(suggestions[0].title == items[3].title,
                     "suggestions use the current localized catalog title")
        let unavailable = SettingsSearchSuggestions.suggestions(items: items,
                                                                    isAvailable: { _ in false })
        suite.expect(unavailable.map(\.id) == [.suggestion(.general), .suggestion(.features)],
                     "unavailable feature pages are omitted from suggestions")
        for language in AppLanguage.allCases {
            let strings = SettingsShellStrings.localized(language)
            suite.expect(!strings.suggestions.isEmpty && !strings.recents.isEmpty,
                         "search overlay headings exist in \(language.rawValue)")
        }
        checkNativeLayout(suite)
    }

    private static func checkNativeLayout(_ suite: TestSuite) {
        _ = NSApplication.shared
        let domain = "vorss.tests.native-shell.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let host = NSHostingController(rootView:
            NavigationSplitView(columnVisibility: .constant(.all)) {
                List { Text("General") }
                    .navigationSplitViewColumnWidth(
                        min: SettingsShellLayout.sidebarMinWidth, ideal: 300,
                        max: SettingsShellLayout.sidebarMaxWidth)
                    .background(SettingsSidebarWidthRestorer(width: 300, defaults: defaults))
            } detail: {
                Color.clear.frame(minWidth: SettingsShellLayout.minDetailWidth)
                    .toolbar {
                        ToolbarItemGroup(placement: .navigation) {
                            Button("Back", systemImage: "chevron.backward") {}
                            Button("Forward", systemImage: "chevron.forward") {}
                        }
                    }
            }
            .toolbar(removing: .sidebarToggle)
            .searchable(text: .constant(""), placement: .sidebar)
            .background(SettingsWindowTitle(title: "General")))
        host.sizingOptions = []
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 1040, height: 820))
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        defer { window.close() }
        host.view.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        let split = descendants(host.view).compactMap { $0 as? NSSplitView }.first
        let controller = split?.delegate as? NSSplitViewController
        let sidebar = controller?.splitViewItems.first
        suite.expect(sidebar?.viewController.view.frame.width == 300,
                     "the native split view restores the chosen width after layout settles")
        suite.expect(sidebar?.canCollapse == false && sidebar?.canCollapseFromWindowResize == false,
                     "native navigation disables both divider and resize collapse")
        suite.expect(window.title == "General",
                     "the current destination supplies the real native window title")
        suite.expect(window.toolbar?.items.count == 2,
                     "navigation controls occupy the native toolbar without a sidebar toggle")
        suite.expect(descendants(host.view).contains { $0 is NSSearchField },
                     "sidebar search is supplied by native navigation, not a separate text field")
        split?.setPosition(325, ofDividerAt: 0)
        suite.expect(sidebar?.viewController.view.frame.width == 325,
                     "restoring a width leaves the divider user-resizable")
        suite.expect(SettingsShellLayout.storedSidebarWidth(defaults: defaults) == 325,
                     "a divider drag is saved without a debounce that can be lost at close")
        split?.setPosition(0, ofDividerAt: 0)
        suite.expect((sidebar?.viewController.view.frame.width ?? 0) >= SettingsShellLayout.sidebarMinWidth,
                     "the native sidebar cannot be dragged closed")
    }

    private static func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(descendants)
    }
}
