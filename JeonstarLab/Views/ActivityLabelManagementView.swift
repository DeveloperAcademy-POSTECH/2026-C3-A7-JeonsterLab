//
//  ActivityLabelManagementView.swift
//  JeonstarLab
//
//  Created by Seungjun Lee on 5/21/26.
//

import SwiftUI

struct ActivityLabelManagementView: View {

    @State var viewModel: ActivityLabelManagementViewModel
    @State private var showAddSheet = false
    @State private var newLabelName = ""

    var body: some View {
        List {
            if viewModel.labels.isEmpty {
                ContentUnavailableView(
                    "레이블 없음",
                    systemImage: "tag.slash",
                    description: Text("+ 버튼으로 Activity 레이블을 추가하세요.")
                )
            } else {
                ForEach(viewModel.labels) { label in
                    Text(label.name)
                }
                .onDelete { offsets in
                    viewModel.deleteLabel(at: offsets)
                }
            }
        }
        .navigationTitle("Activity 레이블")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newLabelName = ""
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showAddSheet) {
            addLabelSheet
        }
        .onAppear {
            viewModel.load()
        }
    }

    private var addLabelSheet: some View {
        NavigationStack {
            Form {
                Section("레이블 이름") {
                    TextField("예: snap, wave, idle", text: $newLabelName)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("레이블 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { showAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        viewModel.addLabel(name: newLabelName)
                        showAddSheet = false
                    }
                    .disabled(newLabelName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
