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
            Text("데이터셋 내보내기 옵션")
                .font(.title2.weight(.semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    optionSection("필수 항목") {
                        ForEach(DatasetRequiredColumn.allCases) { column in
                            Toggle(column.header, isOn: .constant(true))
                                .disabled(true)
                        }
                    }

                    optionSection("사용자 정보") {
                        ForEach(DatasetUserInfoColumn.allCases) { column in
                            Toggle(column.displayName, isOn: userInfoBinding(for: column))
                        }
                    }

                    optionSection("모션 데이터") {
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
                Button("취소", action: onCancel)
                Button("내보내기", action: onExport)
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
