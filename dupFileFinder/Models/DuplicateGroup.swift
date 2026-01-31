//
//  DuplicateGroup.swift
//  dupFileFinder
//

import Foundation

struct DuplicateGroup: Identifiable, Sendable {
    let id: UUID
    var files: [FileItem]
    let sizePerFile: Int64

    init(id: UUID = UUID(), files: [FileItem], sizePerFile: Int64) {
        self.id = id
        self.files = files
        self.sizePerFile = sizePerFile
    }

    var reclaimableBytes: Int64 {
        guard files.count > 1 else { return 0 }
        return sizePerFile * Int64(files.count - 1)
    }

    var filesToRemove: [FileItem] { files.filter { !$0.isKept } }
}
