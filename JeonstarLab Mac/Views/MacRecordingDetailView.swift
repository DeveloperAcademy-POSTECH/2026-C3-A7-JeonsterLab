//
//  MacRecordingDetailView.swift
//  JeonstarLab Mac
//

import SwiftUI

struct MacRecordingDetailView: View {
    @Binding var package: ReceivedRecordingPackage
    let onSaveLabel: (ReceivedRecordingPackage) -> Void

    @State private var samples: [MotionCSVSample] = []
    @State private var csvErrorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(package.displayTitle)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                sectionCard(title: "녹화 정보") {
                    MacRecordingInfoPanel(package: package)
                }

                sectionCard(title: "라벨") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("결과", selection: $package.label) {
                            ForEach(RecordingPackageLabel.allCases) { label in
                                Text(label.displayName).tag(label)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: package.label) {
                            onSaveLabel(package)
                        }

                        TextEditor(text: $package.notes)
                            .frame(minHeight: 72)
                            .onChange(of: package.notes) {
                                onSaveLabel(package)
                            }
                    }
                }

                if !package.parseMessages.isEmpty {
                    sectionCard(title: "파일 상태") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(package.parseMessages, id: \.self) { message in
                                Text(message)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                sectionCard(title: "스냅 이벤트") {
                    MacSnapEventListView(events: package.snapAnalysis?.snapEvents ?? [])
                }

                sectionCard(title: "그래프") {
                    if let csvErrorMessage {
                        Text(csvErrorMessage)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                    } else if samples.isEmpty {
                        ProgressView("CSV 로딩 중")
                            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                    } else {
                        MacMotionChartsView(samples: samples)
                    }
                }
            }
            .frame(maxWidth: 920, alignment: .leading)
            .padding(28)
        }
        .task(id: package.folderURL) {
            loadCSV()
        }
    }

    private func loadCSV() {
        guard let csvURL = package.csvURL else {
            samples = []
            csvErrorMessage = "recording.csv 파일이 없습니다."
            return
        }

        do {
            samples = try MotionCSVParser.parse(url: csvURL)
            csvErrorMessage = nil
        } catch {
            samples = []
            csvErrorMessage = error.localizedDescription
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
