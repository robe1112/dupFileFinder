//
//  FileHasher.swift
//  dupFileFinder
//

import CryptoKit
import Foundation

enum FileHasher {
    private static let chunkSize = 64 * 1024
    private static let hashingQueue = DispatchQueue(label: "dupFileFinder.hashing", qos: .utility)

    static func sha256(of url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            hashingQueue.async {
                do {
                    var hasher = SHA256()
                    let handle = try FileHandle(forReadingFrom: url)
                    defer { try? handle.close() }
                    var remaining = try handle.seekToEnd()
                    try handle.seek(toOffset: 0)
                    while remaining > 0 {
                        let toRead = min(remaining, UInt64(chunkSize))
                        guard let data = try handle.read(upToCount: Int(toRead)) else { break }
                        hasher.update(data: data)
                        remaining -= UInt64(data.count)
                        if data.count < Int(toRead) { break }
                    }
                    let digest = hasher.finalize()
                    let hex = digest.map { String(format: "%02x", $0) }.joined()
                    continuation.resume(returning: hex)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func verifyByteForByte(_ url1: URL, _ url2: URL) async throws -> Bool {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            hashingQueue.async {
                do {
                    let h1 = try FileHandle(forReadingFrom: url1)
                    let h2 = try FileHandle(forReadingFrom: url2)
                    defer { try? h1.close(); try? h2.close() }
                    let len1 = try h1.seekToEnd()
                    let len2 = try h2.seekToEnd()
                    try h1.seek(toOffset: 0)
                    try h2.seek(toOffset: 0)
                    guard len1 == len2 else {
                        continuation.resume(returning: false)
                        return
                    }
                    var remaining = len1
                    while remaining > 0 {
                        let toRead = min(remaining, UInt64(chunkSize))
                        guard let d1 = try h1.read(upToCount: Int(toRead)),
                              let d2 = try h2.read(upToCount: Int(toRead)),
                              d1 == d2 else {
                            continuation.resume(returning: false)
                            return
                        }
                        remaining -= UInt64(d1.count)
                    }
                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    enum HashError: Error {
        case mismatch
    }
}
