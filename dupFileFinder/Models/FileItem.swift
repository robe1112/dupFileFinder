//
//  FileItem.swift
//  dupFileFinder
//

import Foundation

struct FileItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let size: Int64
    let dateModified: Date
    let dateCreated: Date
    var contentHash: String?
    var isKept: Bool

    init(
        id: UUID = UUID(),
        url: URL,
        size: Int64,
        dateModified: Date,
        dateCreated: Date,
        contentHash: String? = nil,
        isKept: Bool = false
    ) {
        self.id = id
        self.url = url
        self.size = size
        self.dateModified = dateModified
        self.dateCreated = dateCreated
        self.contentHash = contentHash
        self.isKept = isKept
    }

    var filename: String { url.lastPathComponent }
    var path: String { url.path }
}
