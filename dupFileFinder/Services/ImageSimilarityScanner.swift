//
//  ImageSimilarityScanner.swift
//  dupFileFinder
//

import AppKit
import Foundation
import Vision

enum ImageSimilarityScanner {
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "heif", "bmp", "tiff", "tif", "webp"]

    static func findSimilarGroups(
        files: [FileItem],
        distanceThreshold: Float,
        progress: @escaping (Double, String) -> Void
    ) async -> [DuplicateGroup] {
        let imageFiles = files.filter { imageExtensions.contains($0.url.pathExtension.lowercased()) }
        guard imageFiles.count > 1 else { return [] }
        var observations: [(FileItem, VNFeaturePrintObservation)] = []
        for (index, item) in imageFiles.enumerated() {
            if Task.isCancelled { break }
            progress(Double(index) / Double(imageFiles.count) * 0.5, "Computing image features…")
            guard let obs = await featurePrint(for: item.url) else { continue }
            observations.append((item, obs))
        }
        progress(0.5, "Comparing images…")
        var groups: [[FileItem]] = []
        var used = Set<Int>()
        let count = observations.count
        for i in 0..<count {
            if Task.isCancelled { break }
            if used.contains(i) { continue }
            var group = [observations[i].0]
            used.insert(i)
            for j in (i + 1)..<count {
                if used.contains(j) { continue }
                do {
                    var distance: Float = 0
                    try observations[i].1.computeDistance(&distance, to: observations[j].1)
                    if distance <= distanceThreshold {
                        group.append(observations[j].0)
                        used.insert(j)
                    }
                } catch { continue }
            }
            if group.count > 1 {
                groups.append(group)
            }
            if (i + 1) % 10 == 0 {
                progress(0.5 + 0.5 * Double(i + 1) / Double(count), "Comparing images…")
            }
        }
        progress(1, "Done")
        return groups.map { files in
            let sizePerFile = files[0].size
            return DuplicateGroup(files: files, sizePerFile: sizePerFile)
        }
    }

    private static func featurePrint(for url: URL) async -> VNFeaturePrintObservation? {
        await withCheckedContinuation { (continuation: CheckedContinuation<VNFeaturePrintObservation?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = NSImage(contentsOf: url),
                      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    continuation.resume(returning: nil)
                    return
                }
                let request = VNGenerateImageFeaturePrintRequest()
                request.revision = VNGenerateImageFeaturePrintRequestRevision1
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    guard let result = request.results?.first as? VNFeaturePrintObservation else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
