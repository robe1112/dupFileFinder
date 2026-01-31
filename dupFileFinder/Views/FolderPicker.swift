//
//  FolderPicker.swift
//  dupFileFinder
//

import AppKit
import SwiftUI

struct FolderPicker {
    static func pickFolders() -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.title = "Choose folders to scan"
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }

    static func pickSingleFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Choose backup folder"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url
    }
}
