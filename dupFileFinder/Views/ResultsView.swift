//
//  ResultsView.swift
//  dupFileFinder
//

import AppKit
import SwiftUI

struct ResultsView: View {
    @Bindable var scanner: DuplicateScanner
    var isSimilarResults: Bool = false
    @Binding var backupBeforeRemove: Bool
    @Binding var backupFolderURL: URL?

    private var groups: [DuplicateGroup] { scanner.duplicateGroups }
    private var filesToRemoveCount: Int { scanner.filesToRemove().count }
    private var selectedReclaimableBytes: Int64 {
        scanner.filesToRemove().reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryBar
            Divider()
            if groups.isEmpty {
                emptyState
            } else {
                List(groups) { group in
                    DuplicateGroupRow(scanner: scanner, group: group)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private var summaryBar: some View {
        HStack {
            if isSimilarResults {
                Text("\(groups.count) similar image groups")
                Text("(not identical)")
                    .foregroundStyle(.secondary)
            } else {
                Text("\(groups.count) duplicate groups")
            }
            Text("•")
            Text("\(scanner.totalDuplicateFiles) files")
            Text("•")
            Text(scanner.reclaimableBytes.formatted(.byteCount(style: .file)))
                .help("Reclaimable space if you remove duplicates")
            Spacer()
            Menu("Smart selection") {
                Button("Keep newest in each group") {
                    scanner.applyKeepNewestInEachGroup()
                }
                Button("Keep oldest in each group") {
                    scanner.applyKeepOldestInEachGroup()
                }
                Button("Keep shortest path in each group") {
                    scanner.applyKeepShortestPathInEachGroup()
                }
                Divider()
                Button("Keep file in Documents if present") {
                    scanner.applyKeepPreferredFolderInEachGroup(folderName: "Documents")
                }
            }
            .disabled(groups.isEmpty)
            Toggle("Backup before removing", isOn: $backupBeforeRemove)
                .toggleStyle(.checkbox)
            if backupBeforeRemove {
                Button(backupFolderURL?.path ?? "Choose backup folder…") {
                    if let url = FolderPicker.pickSingleFolder() {
                        backupFolderURL = url
                    }
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Choose backup folder")
            }
            if filesToRemoveCount > 0 {
                Button("Remove \(filesToRemoveCount) selected") {
                    removeSelected()
                }
                .keyboardShortcut(.deleteForward, modifiers: .command)
                .accessibilityLabel("Remove selected duplicate files")
                .accessibilityHint("Moves the selected files to Trash")
            }
            if !scanner.lastTrashedForUndo.isEmpty {
                Button("Undo last removal") {
                    scanner.undoLastRemoval()
                }
                .accessibilityLabel("Undo last removal")
                .accessibilityHint("Moves the last trashed files back to their original locations")
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No duplicates found",
            systemImage: "checkmark.circle",
            description: Text("No duplicate files were found in the selected folders.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func removeSelected() {
        let toRemove = scanner.filesToRemove()
        let urls = toRemove.map(\.url)
        do {
            let backupDir = backupBeforeRemove ? backupFolderURL : nil
            let results = try FileRemover.moveToTrash(urls: urls, backupDirectory: backupDir)
            scanner.lastTrashedForUndo = results.map { (original: $0.key, trash: $0.value) }
            scanner.removeTrashedFiles(urls: Set(urls))
        } catch {
            // TODO: show error alert
        }
    }
}

struct DuplicateGroupRow: View {
    @Bindable var scanner: DuplicateScanner
    let group: DuplicateGroup

    var body: some View {
        DisclosureGroup {
            ForEach(group.files) { file in
                HStack(alignment: .top) {
                    Button {
                        scanner.setKept(groupId: group.id, fileId: file.id)
                    } label: {
                        Image(systemName: file.isKept ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(file.isKept ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(file.isKept ? "Keeping this file" : "Keep this file")
                    .accessibilityLabel(file.isKept ? "Keeping this file" : "Keep this file")
                    .accessibilityAddTraits(file.isKept ? [.isButton, .isSelected] : .isButton)
                    Image(systemName: "doc")
                        .accessibilityHidden(true)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.filename)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(file.url.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Text(file.size.formatted(.byteCount(style: .file)))
                        .foregroundStyle(.secondary)
                    Text(file.dateModified.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                    Button("Preview") {
                        NSWorkspace.shared.open(file.url)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Preview file")
                    .accessibilityHint("Opens the file in its default application")
                }
                .padding(.vertical, 4)
            }
        } label: {
            HStack {
                Text("\(group.files.count) copies")
                    .fontWeight(.medium)
                Text("•")
                Text(group.sizePerFile.formatted(.byteCount(style: .file)))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ResultsView(
        scanner: DuplicateScanner(),
        isSimilarResults: false,
        backupBeforeRemove: .constant(false),
        backupFolderURL: .constant(nil)
    )
    .frame(width: 500, height: 400)
}
