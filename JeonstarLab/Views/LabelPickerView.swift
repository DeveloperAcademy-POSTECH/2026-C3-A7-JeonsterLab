//
//  LabelPickerView.swift
//  JeonstarLab
//
//  Created by Seungjun Lee on 5/21/26.
//

import SwiftUI

struct LabelPickerView: View {

    let labels:   [ActivityLabel]
    let selected: UUID?
    let onSelect: (UUID?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                noneRow
                ForEach(labels, id: \.id) { label in
                    labelRow(label)
                }
            }
            .navigationTitle("레이블 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }

    private var noneRow: some View {
        Button {
            onSelect(nil)
            dismiss()
        } label: {
            HStack {
                Text("레이블 없음").foregroundStyle(.secondary)
                Spacer()
                if selected == nil {
                    Image(systemName: "checkmark").foregroundStyle(.blue)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private func labelRow(_ label: ActivityLabel) -> some View {
        Button {
            onSelect(label.id)
            dismiss()
        } label: {
            HStack {
                Text(label.name)
                Spacer()
                if selected == label.id {
                    Image(systemName: "checkmark").foregroundStyle(.blue)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}
