//
//  FileRemover.swift
//  dupFileFinder
//

import Foundation

enum FileRemover {
    static func moveToTrash(urls: [URL], backupDirectory: URL? = nil) throws -> [URL: URL] {
        let fm = FileManager.default
        if let backup = backupDirectory {
            try fm.createDirectory(at: backup, withIntermediateDirectories: true)
        }
        var results: [URL: URL] = [:]
        for url in urls {
            if ScanConfig.isURLProtectedStatic(url) { continue }
            if let backup = backupDirectory {
                let name = url.lastPathComponent
                var dest = backup.appendingPathComponent(name)
                if fm.fileExists(atPath: dest.path) {
                    let base = url.deletingPathExtension().lastPathComponent
                    let ext = url.pathExtension
                    var counter = 1
                    repeat {
                        dest = backup.appendingPathComponent("\(base)_\(counter).\(ext)")
                        counter += 1
                    } while fm.fileExists(atPath: dest.path)
                }
                try fm.copyItem(at: url, to: dest)
            }
            var resultingURL: NSURL?
            try fm.trashItem(at: url, resultingItemURL: &resultingURL)
            if let resultURL = resultingURL as? URL {
                results[url] = resultURL
            }
        }
        return results
    }

    static func moveFromTrashBackToOriginal(entries: [(original: URL, trash: URL)]) throws {
        let fm = FileManager.default
        for (original, trash) in entries {
            if fm.fileExists(atPath: trash.path) {
                try fm.moveItem(at: trash, to: original)
            }
        }
    }

    static func isProtected(_ url: URL) -> Bool {
        ScanConfig.isURLProtectedStatic(url)
    }
}
