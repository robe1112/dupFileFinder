//
//  ContentView.swift
//  dupFileFinder
//

import SwiftUI

struct ContentView: View {
    @State private var folderURLs: [URL] = []
    @State private var scanner = DuplicateScanner()
    @State private var hasScanned = false
    @State private var minimumFileSizeString = "0"
    @State private var allowedExtensionsString = ""
    @State private var skipHiddenFiles = true
    @State private var verifyWithByteComparison = false
    @State private var scanMode: ScanMode = .exactDuplicates
    @State private var similaritySensitivity: SimilaritySensitivity = .medium
    @State private var backupBeforeRemove = false
    @State private var backupFolderURL: URL?

    enum ScanMode: String, CaseIterable {
        case exactDuplicates = "Exact duplicates"
        case similarImages = "Similar images"
    }

    enum SimilaritySensitivity: String, CaseIterable {
        case strict = "Strict"
        case medium = "Medium"
        case loose = "Loose"
        var distanceThreshold: Float {
            switch self {
            case .strict: return 0.3
            case .medium: return 0.5
            case .loose: return 1.0
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if scanner.isScanning {
                scanningOverlay
            }
            if hasScanned && !scanner.isScanning {
                ResultsView(
                    scanner: scanner,
                    isSimilarResults: scanner.isSimilarImageResults,
                    backupBeforeRemove: $backupBeforeRemove,
                    backupFolderURL: $backupFolderURL
                )
            } else if !scanner.isScanning {
                welcomeView
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private var toolbar: some View {
        HStack {
            Button("Add Folders…") {
                let urls = FolderPicker.pickFolders()
                for url in urls where !folderURLs.contains(where: { $0.path == url.path }) {
                    folderURLs.append(url)
                }
            }
            .keyboardShortcut("o", modifiers: .command)
            .accessibilityLabel("Add folders to scan")
            Button("Clear folders", systemImage: "trash") {
                folderURLs.removeAll()
            }
            .disabled(folderURLs.isEmpty)
            .accessibilityLabel("Clear all folders")
            Picker("Mode", selection: $scanMode) {
                ForEach([ContentView.ScanMode.exactDuplicates, .similarImages], id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .disabled(scanner.isScanning)
            if scanMode == .similarImages {
                Picker("Sensitivity", selection: $similaritySensitivity) {
                    ForEach([ContentView.SimilaritySensitivity.strict, .medium, .loose], id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
                .disabled(scanner.isScanning)
            }
            Spacer()
            Button("Scan") {
                runScan()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(folderURLs.isEmpty || scanner.isScanning)
            .accessibilityLabel("Start scan")
            if scanner.isScanning {
                Button("Cancel") {
                    scanner.cancel()
                }
                .accessibilityLabel("Cancel scan")
            }
        }
        .padding(12)
        .background(.bar)
    }

    private var scanningOverlay: some View {
        VStack(spacing: 12) {
            ProgressView(value: scanner.progress)
                .progressViewStyle(.linear)
                .frame(maxWidth: 300)
            Text(scanner.progressMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Add folders to scan for duplicate files")
                .font(.headline)
            Text("Duplicate files are found by content (hash), not just name or size.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            if !folderURLs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected folders:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(folderURLs, id: \.path) { url in
                        HStack {
                            Text(url.path)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("Remove", systemImage: "xmark.circle") {
                                folderURLs.removeAll { $0.path == url.path }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .padding()
                ScanOptionsView(
                    minimumFileSizeString: $minimumFileSizeString,
                    allowedExtensionsString: $allowedExtensionsString,
                    skipHiddenFiles: $skipHiddenFiles,
                    verifyWithByteComparison: $verifyWithByteComparison
                )
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func runScan() {
        hasScanned = true
        let minSize = Int64(minimumFileSizeString.trimmingCharacters(in: .whitespaces)) ?? 0
        let exts: Set<String>? = {
            let s = allowedExtensionsString.trimmingCharacters(in: .whitespaces)
            guard !s.isEmpty else { return nil }
            return Set(s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty })
        }()
        let config = ScanConfig(
            folderURLs: folderURLs,
            minimumFileSize: minSize,
            allowedExtensions: exts,
            skipHiddenFiles: skipHiddenFiles,
            verifyWithByteComparison: verifyWithByteComparison
        )
        Task {
            if scanMode == .similarImages {
                await scanner.scanSimilarImages(config: config, distanceThreshold: similaritySensitivity.distanceThreshold)
            } else {
                await scanner.scan(config: config)
            }
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 600, height: 500)
}
