//
//  DatasetExportOptionsView.swift
//  JeonstarLab Mac
//

import SwiftUI

struct DatasetExportOptionsView: View {
    @Binding var options: DatasetExportOptions
    let onCancel: () -> Void
    let onExport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Export Dataset")
                .font(.title2.weight(.semibold))

            Text("Choose which columns to include in your CSV dataset.")
                .foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    optionSection("Required Columns") {
                        HStack(spacing: 20) {
                            ForEach(DatasetRequiredColumn.allCases) { column in
                                Label(column.header, systemImage: "checkmark.lock.fill")
                                    .font(.callout.monospaced())
                            }
                        }
                        Text("Always included to identify and label each sample.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    optionSection("Participant Information") {
                        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 10) {
                            ForEach(DatasetUserInfoColumn.allCases) { column in
                                Toggle(column.displayName, isOn: userInfoBinding(for: column))
                            }
                        }
                    }

                    optionSection("Motion Data") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), alignment: .leading)], alignment: .leading, spacing: 10) {
                            ForEach(DatasetMotionColumn.allCases) { column in
                                Toggle(column.displayName, isOn: motionBinding(for: column))
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 460)

            Divider()
            HStack {
                Text("Selections are remembered for your next export.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Export", action: onExport)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 640)
        .toggleStyle(.checkbox)
        .background(EditorPalette.background)
    }

    private func optionSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorSurface()
    }

    private func userInfoBinding(for column: DatasetUserInfoColumn) -> Binding<Bool> {
        Binding(
            get: { options.userInfoColumns.contains(column) },
            set: { isSelected in
                if isSelected {
                    options.userInfoColumns.insert(column)
                } else {
                    options.userInfoColumns.remove(column)
                }
            }
        )
    }

    private func motionBinding(for column: DatasetMotionColumn) -> Binding<Bool> {
        Binding(
            get: { options.motionColumns.contains(column) },
            set: { isSelected in
                if isSelected {
                    options.motionColumns.insert(column)
                } else {
                    options.motionColumns.remove(column)
                }
            }
        )
    }
}
