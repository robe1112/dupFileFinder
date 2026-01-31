//
//  DuplicateScanner.swift
//  dupFileFinder
//

import Foundation

@Observable
final class DuplicateScanner {
    var isSimilarImageResults = false
    var lastTrashedForUndo: [(original: URL, trash: URL)] = []
    var isScanning = false
    var progress: Double = 0
    var progressMessage: String = ""
    var duplicateGroups: [DuplicateGroup] = []
    var totalFilesScanned: Int = 0
    var totalDuplicateFiles: Int = 0
    var reclaimableBytes: Int64 = 0

    private var cancellationTask: Task<Void, Never>?

    func scan(config: ScanConfig) async {
        guard !config.folderURLs.isEmpty else { return }
        cancellationTask?.cancel()
        isScanning = true
        progress = 0
        progressMessage = "Enumerating files…"
        duplicateGroups = []
        totalFilesScanned = 0
        totalDuplicateFiles = 0
        reclaimableBytes = 0
        isSimilarImageResults = false
        lastTrashedForUndo = []

        let task = Task {
            do {
                let files = await enumerateFiles(config: config)
                totalFilesScanned = files.count
                if Task.isCancelled { throw CancellationError() }
                progressMessage = "Hashing files (grouped by size)…"
                let groups = await findDuplicateGroups(files: files, config: config)
                if Task.isCancelled { throw CancellationError() }
                duplicateGroups = groups
                applyKeepNewestInEachGroup()
                totalDuplicateFiles = groups.flatMap(\.files).count
                reclaimableBytes = groups.reduce(0) { $0 + $1.reclaimableBytes }
                progress = 1
                progressMessage = "Done"
            } catch is CancellationError {
                progressMessage = "Cancelled"
            } catch {
                progressMessage = "Error: \(error.localizedDescription)"
            }
            isScanning = false
        }
        cancellationTask = task
        await task.value
    }

    func scanSimilarImages(config: ScanConfig, distanceThreshold: Float = 0.5) async {
        guard !config.folderURLs.isEmpty else { return }
        cancellationTask?.cancel()
        isScanning = true
        progress = 0
        progressMessage = "Enumerating files…"
        duplicateGroups = []
        totalFilesScanned = 0
        totalDuplicateFiles = 0
        reclaimableBytes = 0
        isSimilarImageResults = true
        lastTrashedForUndo = []

        let task = Task {
            do {
                let files = await enumerateFiles(config: config)
                totalFilesScanned = files.count
                if Task.isCancelled { throw CancellationError() }
                let groups = await ImageSimilarityScanner.findSimilarGroups(files: files, distanceThreshold: distanceThreshold) { [self] p, msg in
                    Task { @MainActor in
                        self.progress = p
                        self.progressMessage = msg
                    }
                }
                if Task.isCancelled { throw CancellationError() }
                duplicateGroups = groups
                applyKeepNewestInEachGroup()
                totalDuplicateFiles = groups.flatMap(\.files).count
                reclaimableBytes = groups.reduce(0) { $0 + $1.reclaimableBytes }
                progress = 1
                progressMessage = "Done"
            } catch is CancellationError {
                progressMessage = "Cancelled"
            } catch {
                progressMessage = "Error: \(error.localizedDescription)"
            }
            isScanning = false
        }
        cancellationTask = task
        await task.value
    }

    func cancel() {
        cancellationTask?.cancel()
    }

    func setKept(groupId: UUID, fileId: UUID) {
        guard let groupIndex = duplicateGroups.firstIndex(where: { $0.id == groupId }) else { return }
        for i in duplicateGroups[groupIndex].files.indices {
            duplicateGroups[groupIndex].files[i].isKept = duplicateGroups[groupIndex].files[i].id == fileId
        }
    }

    func applyKeepNewestInEachGroup() {
        for groupIndex in duplicateGroups.indices {
            guard let idx = duplicateGroups[groupIndex].files.indices.max(by: { duplicateGroups[groupIndex].files[$0].dateModified < duplicateGroups[groupIndex].files[$1].dateModified }) else { continue }
            for i in duplicateGroups[groupIndex].files.indices {
                duplicateGroups[groupIndex].files[i].isKept = (i == idx)
            }
        }
    }

    func applyKeepOldestInEachGroup() {
        for groupIndex in duplicateGroups.indices {
            guard let idx = duplicateGroups[groupIndex].files.indices.min(by: { duplicateGroups[groupIndex].files[$0].dateModified < duplicateGroups[groupIndex].files[$1].dateModified }) else { continue }
            for i in duplicateGroups[groupIndex].files.indices {
                duplicateGroups[groupIndex].files[i].isKept = (i == idx)
            }
        }
    }

    func applyKeepShortestPathInEachGroup() {
        for groupIndex in duplicateGroups.indices {
            guard let idx = duplicateGroups[groupIndex].files.indices.min(by: { duplicateGroups[groupIndex].files[$0].path.count < duplicateGroups[groupIndex].files[$1].path.count }) else { continue }
            for i in duplicateGroups[groupIndex].files.indices {
                duplicateGroups[groupIndex].files[i].isKept = (i == idx)
            }
        }
    }

    func applyKeepPreferredFolderInEachGroup(folderName: String) {
        let name = folderName.lowercased()
        for groupIndex in duplicateGroups.indices {
            let files = duplicateGroups[groupIndex].files
            guard let idx = files.indices.max(by: { a, b in
                let pathA = files[a].path.lowercased()
                let pathB = files[b].path.lowercased()
                let scoreA = pathA.contains("/\(name)/") ? 1 : 0
                let scoreB = pathB.contains("/\(name)/") ? 1 : 0
                if scoreA != scoreB { return scoreA < scoreB }
                return pathA.count > pathB.count
            }) else { continue }
            for i in duplicateGroups[groupIndex].files.indices {
                duplicateGroups[groupIndex].files[i].isKept = (i == idx)
            }
        }
    }

    func filesToRemove() -> [FileItem] {
        duplicateGroups.flatMap(\.filesToRemove)
    }

    func undoLastRemoval() {
        guard !lastTrashedForUndo.isEmpty else { return }
        do {
            try FileRemover.moveFromTrashBackToOriginal(entries: lastTrashedForUndo)
            lastTrashedForUndo = []
        } catch {
            // TODO: show error
        }
    }

    func removeTrashedFiles(urls: Set<URL>) {
        duplicateGroups = duplicateGroups.compactMap { group in
            let remaining = group.files.filter { !urls.contains($0.url) }
            guard remaining.count > 1 else { return nil }
            var files = remaining
            if let newestIndex = files.indices.max(by: { files[$0].dateModified < files[$1].dateModified }) {
                for i in files.indices { files[i].isKept = (i == newestIndex) }
            }
            return DuplicateGroup(id: group.id, files: files, sizePerFile: group.sizePerFile)
        }
        totalDuplicateFiles = duplicateGroups.flatMap(\.files).count
        reclaimableBytes = duplicateGroups.reduce(0) { $0 + $1.reclaimableBytes }
    }

    private func enumerateFiles(config: ScanConfig) async -> [FileItem] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[FileItem], Never>) in
            DispatchQueue.global(qos: .utility).async {
                var result: [FileItem] = []
                let fm = FileManager.default
                for baseURL in config.folderURLs {
                    guard let enumerator = fm.enumerator(
                        at: baseURL,
                        includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .creationDateKey, .isHiddenKey],
                        options: [],
                        errorHandler: { _, _ in true }
                    ) else { continue }
                    while let url = enumerator.nextObject() as? URL {
                        var isDir: ObjCBool = false
                        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else { continue }
                        if config.skipHiddenFiles, (try? url.resourceValues(forKeys: [.isHiddenKey]))?.isHidden == true { continue }
                        let pathComponents = url.pathComponents
                        if pathComponents.contains(where: { config.excludedPathComponents.contains($0) }) { continue }
                        if config.isURLProtected(url) { continue }
                        guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size > 0 else { continue }
                        if Int64(size) < config.minimumFileSize { continue }
                        if let exts = config.allowedExtensions, !exts.isEmpty {
                            let ext = url.pathExtension.lowercased()
                            if ext.isEmpty || !exts.contains(ext) { continue }
                        }
                        let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                        let created = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                        result.append(FileItem(url: url, size: Int64(size), dateModified: mod, dateCreated: created))
                    }
                }
                continuation.resume(returning: result)
            }
        }
    }

    private func findDuplicateGroups(files: [FileItem], config: ScanConfig) async -> [DuplicateGroup] {
        var bySize: [Int64: [FileItem]] = [:]
        for f in files {
            bySize[f.size, default: []].append(f)
        }
        let candidateGroups = bySize.values.filter { $0.count > 1 }
        var hashToFiles: [String: [FileItem]] = [:]
        let total = candidateGroups.reduce(0) { $0 + $1.count }
        var processed = 0
        for group in candidateGroups {
            if Task.isCancelled { break }
            var byHash: [String: [FileItem]] = [:]
            for item in group {
                do {
                    let h = try await FileHasher.sha256(of: item.url)
                    var copy = item
                    copy.contentHash = h
                    byHash[h, default: []].append(copy)
                } catch { continue }
                processed += 1
                await MainActor.run {
                    self.progress = total > 0 ? Double(processed) / Double(total) * 0.95 : 0
                }
            }
            for (hash, items) in byHash where items.count > 1 {
                hashToFiles[hash] = items
            }
        }
        if config.verifyWithByteComparison {
            for (hash, items) in hashToFiles where items.count > 1 {
                var verified: [FileItem] = []
                let first = items[0]
                verified.append(first)
                for item in items.dropFirst() {
                    if (try? await FileHasher.verifyByteForByte(first.url, item.url)) == true {
                        verified.append(item)
                    }
                }
                if verified.count > 1 {
                    hashToFiles[hash] = verified
                } else {
                    hashToFiles.removeValue(forKey: hash)
                }
            }
        }
        return hashToFiles.values
            .filter { $0.count > 1 }
            .map { DuplicateGroup(files: $0, sizePerFile: $0[0].size) }
    }
}
