//
//  RecordingDetailView.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import SwiftUI
import Charts
import MultipeerConnectivity

struct RecordingDetailView: View {

    @State var viewModel: RecordingDetailViewModel
    @State private var selectedSnapEventIndex: Int = 0
    @State private var exportURLs: [URL] = []
    @State private var isShareSheetPresented = false
    @State private var isExporting = false
    @State private var exportErrorMessage: String?
    @State private var macConnectionViewModel = MacConnectionViewModel.shared

    var body: some View {
        List {
            // MARK: 정보 섹션
            Section("정보") {
                LabeledContent("날짜", value: viewModel.title)
                LabeledContent("길이", value: viewModel.durationText)
                LabeledContent("샘플", value: viewModel.sampleCountText)
            }

            Section("Mac 전송") {
                LabeledContent("Mac 연결 상태", value: macConnectionViewModel.connectionStatusText)
                LabeledContent("Mac", value: macConnectionViewModel.connectedMacText)
                LabeledContent("전송", value: macConnectionViewModel.transferStatusText)

                Text(macConnectionViewModel.guidanceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !macConnectionViewModel.discoveredMacs.isEmpty,
                   macConnectionViewModel.connectionStatus == .searching {
                    ForEach(macConnectionViewModel.discoveredMacs, id: \.self) { mac in
                        HStack {
                            Label(mac.displayName, systemImage: "desktopcomputer")
                            Spacer()
                            Button("연결") {
                                macConnectionViewModel.selectMac(mac)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }

                Toggle("Mac 연결 시 자동 전송", isOn: Binding(
                    get: { macConnectionViewModel.isAutomaticTransferEnabled },
                    set: { macConnectionViewModel.isAutomaticTransferEnabled = $0 }
                ))

                Text(macConnectionViewModel.automaticTransferGuidanceText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let errorMessage = macConnectionViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Button("Mac 찾기") {
                        macConnectionViewModel.startSearching()
                    }

                    Button("Mac으로 전송") {
                        macConnectionViewModel.sendRecording(
                            session: viewModel.currentSession,
                            repository: viewModel.recordingRepository
                        )
                    }
                    .disabled(!macConnectionViewModel.canSendToMac)
                }
            }

            // MARK: 그래프 섹션
            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("로딩 중…")
                        Spacer()
                    }
                    .padding(.vertical)
                }
            } else if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            } else if !viewModel.samples.isEmpty {
                let snapResult = AnalyzeSnapUseCase.execute(samples: viewModel.samples)
                let selectedEvent = snapResult.event(at: selectedSnapEventIndex)

                Section("스냅 분석 요약") {
                    SnapAnalysisSummaryView(
                        result: snapResult,
                        selectedEventIndex: $selectedSnapEventIndex
                    )
                }

                Section("사용자 가속도") {
                    accelerationChart(selectedEvent: selectedEvent)
                }

                Section("자이로스코프") {
                    gyroChart(selectedEvent: selectedEvent)
                }

                Section("자세 (Attitude)") {
                    attitudeChart(selectedEvent: selectedEvent)
                }

                Section("3D 사용자 가속도") {
                    MotionTrajectory3DView(
                        samples: viewModel.samples,
                        kind: .userAcceleration
                    )
                }

                Section("3D 자이로스코프") {
                    MotionTrajectory3DView(
                        samples: viewModel.samples,
                        kind: .gyroscope
                    )
                }

                Section("3D 자세") {
                    MotionTrajectory3DView(
                        samples: viewModel.samples,
                        kind: .attitude
                    )
                }
            }
        }
        .navigationTitle("녹화 상세")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    exportRecording()
                } label: {
                    if isExporting {
                        ProgressView()
                    } else {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(isExporting)
            }
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ShareSheet(activityItems: exportURLs)
        }
        .alert("내보내기 실패", isPresented: exportErrorBinding) {
            Button("확인", role: .cancel) {
                exportErrorMessage = nil
            }
        } message: {
            Text(exportErrorMessage ?? "알 수 없는 오류가 발생했습니다.")
        }
        .task {
            await viewModel.loadSamples()
        }
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    exportErrorMessage = nil
                }
            }
        )
    }

    private func exportRecording() {
        Task { @MainActor in
            isExporting = true
            defer { isExporting = false }

            do {
                exportURLs = try viewModel.exportRecording()
                isShareSheetPresented = true
            } catch {
                exportErrorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Charts

    private func accelerationChart(selectedEvent: SnapEventSummary?) -> some View {
        Chart(Array(viewModel.samples.enumerated()), id: \.offset) { i, s in
            LineMark(x: .value("t", i), y: .value("X", s.userAccX))
                .foregroundStyle(by: .value("축", "X"))
            LineMark(x: .value("t", i), y: .value("Y", s.userAccY))
                .foregroundStyle(by: .value("축", "Y"))
            LineMark(x: .value("t", i), y: .value("Z", s.userAccZ))
                .foregroundStyle(by: .value("축", "Z"))

            if let selectedEvent {
                snapRangeMarks(for: selectedEvent)
            }
        }
        .chartXAxis(.hidden)
        .frame(height: 120)
    }

    private func gyroChart(selectedEvent: SnapEventSummary?) -> some View {
        Chart(Array(viewModel.samples.enumerated()), id: \.offset) { i, s in
            LineMark(x: .value("t", i), y: .value("X", s.rotationRateX))
                .foregroundStyle(by: .value("축", "X"))
            LineMark(x: .value("t", i), y: .value("Y", s.rotationRateY))
                .foregroundStyle(by: .value("축", "Y"))
            LineMark(x: .value("t", i), y: .value("Z", s.rotationRateZ))
                .foregroundStyle(by: .value("축", "Z"))

            if let selectedEvent {
                snapRangeMarks(for: selectedEvent)
            }
        }
        .chartXAxis(.hidden)
        .frame(height: 120)
    }

    private func attitudeChart(selectedEvent: SnapEventSummary?) -> some View {
        Chart(Array(viewModel.samples.enumerated()), id: \.offset) { i, s in
            LineMark(x: .value("t", i), y: .value("Roll", s.attitudeRoll))
                .foregroundStyle(by: .value("축", "Roll"))
            LineMark(x: .value("t", i), y: .value("Pitch", s.attitudePitch))
                .foregroundStyle(by: .value("축", "Pitch"))
            LineMark(x: .value("t", i), y: .value("Yaw", s.attitudeYaw))
                .foregroundStyle(by: .value("축", "Yaw"))

            if let selectedEvent {
                snapRangeMarks(for: selectedEvent)
            }
        }
        .chartXAxis(.hidden)
        .frame(height: 120)
    }

    @ChartContentBuilder
    private func snapRangeMarks(for event: SnapEventSummary) -> some ChartContent {
        RuleMark(x: .value("Snap Start", event.startIndex))
            .foregroundStyle(.orange.opacity(0.45))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

        RuleMark(x: .value("Snap Peak", event.peakIndex))
            .foregroundStyle(.red)
            .lineStyle(StrokeStyle(lineWidth: 2))

        RuleMark(x: .value("Snap End", event.endIndex))
            .foregroundStyle(.orange.opacity(0.45))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
    }
}
