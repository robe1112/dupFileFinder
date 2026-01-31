//
//  ScanOptionsView.swift
//  dupFileFinder
//

import SwiftUI

struct ScanOptionsView: View {
    @Binding var minimumFileSizeString: String
    @Binding var allowedExtensionsString: String
    @Binding var skipHiddenFiles: Bool
    @Binding var verifyWithByteComparison: Bool

    var body: some View {
        DisclosureGroup("Scan options") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Minimum file size (bytes):")
                    TextField("0", text: $minimumFileSizeString)
                        .frame(width: 100)
                    Text("(0 = no minimum)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Extensions only (comma-separated):")
                    TextField("e.g. jpg, png", text: $allowedExtensionsString)
                        .frame(minWidth: 150)
                    Text("(leave empty for all)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Skip hidden files", isOn: $skipHiddenFiles)
                Toggle("Verify with byte-for-byte comparison (slower)", isOn: $verifyWithByteComparison)
            }
            .padding(.vertical, 8)
        }
    }
}
