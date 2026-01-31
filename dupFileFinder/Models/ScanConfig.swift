//
//  ScanConfig.swift
//  dupFileFinder
//

import Foundation

struct ScanConfig: Sendable {
    var folderURLs: [URL]
    var excludedPathComponents: Set<String>
    var minimumFileSize: Int64
    var allowedExtensions: Set<String>?
    var skipHiddenFiles: Bool
    var verifyWithByteComparison: Bool

    static let defaultExcludedComponents: Set<String> = [
        ".git", "node_modules", ".Trash", ".DS_Store",
        "Caches", "Application Support"
    ]

    static let protectedPathPrefixes: [String] = [
        "/System", "/Library", "/usr", "/bin", "/sbin", "/private/var"
    ]

    init(
        folderURLs: [URL] = [],
        excludedPathComponents: Set<String> = ScanConfig.defaultExcludedComponents,
        minimumFileSize: Int64 = 0,
        allowedExtensions: Set<String>? = nil,
        skipHiddenFiles: Bool = true,
        verifyWithByteComparison: Bool = false
    ) {
        self.folderURLs = folderURLs
        self.excludedPathComponents = excludedPathComponents
        self.minimumFileSize = minimumFileSize
        self.allowedExtensions = allowedExtensions
        self.skipHiddenFiles = skipHiddenFiles
        self.verifyWithByteComparison = verifyWithByteComparison
    }

    func isURLProtected(_ url: URL) -> Bool {
        Self.isURLProtectedStatic(url)
    }

    static func isURLProtectedStatic(_ url: URL) -> Bool {
        let path = url.path
        return protectedPathPrefixes.contains { path.hasPrefix($0) }
    }
}
