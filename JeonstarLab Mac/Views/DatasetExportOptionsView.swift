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

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    optionSection("Required Columns") {
                        ForEach(DatasetRequiredColumn.allCases) { column in
                            Toggle(column.header, isOn: .constant(true))
                                .disabled(true)
                        }
                    }

                    optionSection("Participant Information") {
                        ForEach(DatasetUserInfoColumn.allCases) { column in
                            Toggle(column.displayName, isOn: userInfoBinding(for: column))
                        }
                    }

                    optionSection("Motion Data") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)], alignment: .leading) {
                            ForEach(DatasetMotionColumn.allCases) { column in
                                Toggle(column.displayName, isOn: motionBinding(for: column))
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 460)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Export", action: onExport)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 560)
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
