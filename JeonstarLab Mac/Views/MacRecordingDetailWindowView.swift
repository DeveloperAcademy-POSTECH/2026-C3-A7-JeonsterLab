//
//  MacRecordingDetailWindowView.swift
//  JeonstarLab Mac
//

import SwiftUI

struct MacRecordingDetailWindowView: View {
    let packagePath: String

    @State private var package: ReceivedRecordingPackage?
    @State private var errorMessage: String?

    private let loader = ReceivedRecordingPackageLoader()

    var body: some View {
        Group {
            if let packageBinding {
                MacRecordingDetailView(
                    package: packageBinding,
                    folders: [],
                    folderForEvent: { _, _ in nil },
                    onAddSnapToFolder: { _, _, _ in },
                    onRemoveSnapFromFolder: { _, _, _ in },
                    onSaveLabel: saveLabel(for:)
                )
                .navigationTitle(package?.displayTitle ?? "녹화 상세")
            } else {
                VStack(spacing: 10) {
                    Text("녹화 기록을 열 수 없습니다.")
                        .font(.title3)
                    Text(errorMessage ?? "선택한 녹화 패키지를 찾을 수 없습니다.")
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 520, minHeight: 360)
                .padding()
            }
        }
        .task(id: packagePath) {
            loadPackage()
        }
    }

    private var packageBinding: Binding<ReceivedRecordingPackage>? {
        guard package != nil else { return nil }
        return Binding(
            get: { package! },
            set: { package = $0 }
        )
    }

    private func loadPackage() {
        let folderURL = URL(fileURLWithPath: packagePath)
        guard let loadedPackage = loader.loadPackage(folderURL: folderURL) else {
            package = nil
            errorMessage = "패키지 폴더가 삭제되었거나 필요한 파일을 찾을 수 없습니다."
            return
        }
        package = loadedPackage
        errorMessage = nil
    }

    private func saveLabel(for updatedPackage: ReceivedRecordingPackage) {
        do {
            try loader.saveLabel(package: updatedPackage)
            package = updatedPackage
            errorMessage = nil
        } catch {
            errorMessage = "라벨 저장 실패: \(error.localizedDescription)"
        }
    }
}
