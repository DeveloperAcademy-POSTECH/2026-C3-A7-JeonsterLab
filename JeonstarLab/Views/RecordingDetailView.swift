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
    @State private var snapDetectionModeErrorMessage: String?
    @State private var isSnapDetectionModeConfirmationPresented = false
    @State private var isEditingMemo = false
    @State private var macConnectionViewModel = MacConnectionViewModel.shared

    var body: some View {
        List {
            // MARK: 정보 섹션
            Section("Information") {
                LabeledContent("Date", value: viewModel.title)
                LabeledContent("Duration", value: viewModel.durationText)
                LabeledContent("Samples", value: viewModel.sampleCountText)
            }

            Section("Notes") {
                if isEditingMemo {
                    TextField(
                        "Add notes about this recording.",
                        text: $viewModel.recordingMemo,
                        axis: .vertical
                    )
                    .lineLimit(3...6)

                    HStack {
                        Button("Save") {
                            viewModel.updateRecordingMemo(viewModel.recordingMemo)
                            if viewModel.memoErrorMessage == nil {
                                isEditingMemo = false
                            }
                        }
                        .disabled(!viewModel.hasRecordingMemoChanges)

                        Button("Cancel") {
                            viewModel.resetRecordingMemoDraft()
                            isEditingMemo = false
                        }
                    }
                } else {
                    Button {
                        viewModel.resetRecordingMemoDraft()
                        isEditingMemo = true
                    } label: {
                        HStack(alignment: .top) {
                            Text(viewModel.savedRecordingMemo.isEmpty ? "Add notes about this recording." : viewModel.savedRecordingMemo)
                                .foregroundStyle(viewModel.savedRecordingMemo.isEmpty ? .secondary : .primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button("Edit Notes") {
                        viewModel.resetRecordingMemoDraft()
                        isEditingMemo = true
                    }
                }

                if let memoErrorMessage = viewModel.memoErrorMessage {
                    Text("Failed to save notes: \(memoErrorMessage)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Transfer to Mac") {
                LabeledContent("Mac Connection", value: macConnectionViewModel.connectionStatusText)
                LabeledContent("Mac", value: macConnectionViewModel.connectedMacText)
                LabeledContent("Transfer", value: macConnectionViewModel.transferStatusText)

                Text(macConnectionViewModel.guidanceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !macConnectionViewModel.discoveredMacs.isEmpty,
                   macConnectionViewModel.connectionStatus == .searching {
                    ForEach(macConnectionViewModel.discoveredMacs, id: \.self) { mac in
                        HStack {
                            Label(mac.displayName, systemImage: "desktopcomputer")
                            Spacer()
                            Button("Connect") {
                                macConnectionViewModel.selectMac(mac)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }

                Toggle("Automatically Send to Mac", isOn: Binding(
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
                    Button("Find Mac") {
                        macConnectionViewModel.startSearching()
                    }

                    Button("Send to Mac") {
                        macConnectionViewModel.sendRecording(
                            session: viewModel.currentSession,
                            repository: viewModel.recordingRepository
                        )
                    }
                    .disabled(!macConnectionViewModel.canSendToMac)
                }
            }

            Section("Snap Detection Mode") {
                Text("Choose the motion type used to analyze snaps in this recording.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Detection Mode", selection: $viewModel.pendingSnapDetectionMode) {
                    ForEach(viewModel.availableSnapDetectionModes) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Button("Apply Detection Mode") {
                    isSnapDetectionModeConfirmationPresented = true
                }
                .disabled(!viewModel.canApplySnapDetectionMode)
            }

            // MARK: 그래프 섹션
            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading…")
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
                let snapResult = viewModel.snapAnalysisResult
                let selectedEvent = snapResult?.event(at: selectedSnapEventIndex)

                Section("Snap Analysis") {
                    if let snapResult {
                        SnapAnalysisSummaryView(
                            result: snapResult,
                            selectedEventIndex: $selectedSnapEventIndex
                        )
                    } else {
                        ContentUnavailableView(
                            "No Snaps Detected",
                            systemImage: "waveform.slash",
                            description: Text("Snap detection is set to None.")
                        )
                    }
                }

                Section("User Acceleration") {
                    accelerationChart(selectedEvent: selectedEvent)
                }

                Section("Gyroscope") {
                    gyroChart(selectedEvent: selectedEvent)
                }

                Section("Attitude") {
                    attitudeChart(selectedEvent: selectedEvent)
                }

                Section("3D User Acceleration") {
                    MotionTrajectory3DView(
                        samples: viewModel.samples,
                        kind: .userAcceleration
                    )
                }

                Section("3D Gyroscope") {
                    MotionTrajectory3DView(
                        samples: viewModel.samples,
                        kind: .gyroscope
                    )
                }

                Section("3D Attitude") {
                    MotionTrajectory3DView(
                        samples: viewModel.samples,
                        kind: .attitude
                    )
                }
            }
        }
        .navigationTitle("Recording Detail")
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
        .alert("Export failed", isPresented: exportErrorBinding) {
            Button("OK", role: .cancel) {
                exportErrorMessage = nil
            }
        } message: {
            Text(exportErrorMessage ?? "An unknown error occurred.")
        }
        .alert(snapDetectionModeConfirmationTitle, isPresented: $isSnapDetectionModeConfirmationPresented) {
            Button("Cancel", role: .cancel) { }
            Button("Apply") {
                applySnapDetectionMode()
            }
        } message: {
            Text(snapDetectionModeConfirmationMessage)
        }
        .alert("Failed to save detection mode", isPresented: snapDetectionModeErrorBinding) {
            Button("OK", role: .cancel) {
                snapDetectionModeErrorMessage = nil
            }
        } message: {
            Text(snapDetectionModeErrorMessage ?? "An unknown error occurred.")
        }
        .task {
            await viewModel.loadSamples()
        }
        .onChange(of: viewModel.appliedSnapDetectionMode) {
            selectedSnapEventIndex = 0
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

    private var snapDetectionModeErrorBinding: Binding<Bool> {
        Binding(
            get: { snapDetectionModeErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    snapDetectionModeErrorMessage = nil
                }
            }
        )
    }

    private var snapDetectionModeConfirmationTitle: String {
        switch viewModel.pendingSnapDetectionMode {
        case .none:
            return "Turn off snap detection?"
        case .jeonFlip:
            return "Use Jeon Flipping for snap detection?"
        }
    }

    private var snapDetectionModeConfirmationMessage: String {
        switch viewModel.pendingSnapDetectionMode {
        case .none:
            return "Charts remain available, but automatically detected snap analysis will be hidden."
        case .jeonFlip:
            return "This recording will be analyzed using the Jeon Flipping motion criteria."
        }
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

    private func applySnapDetectionMode() {
        do {
            try viewModel.applyPendingSnapDetectionMode()
            selectedSnapEventIndex = 0
        } catch {
            snapDetectionModeErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Charts

    private func accelerationChart(selectedEvent: SnapEventSummary?) -> some View {
        Chart(Array(viewModel.samples.enumerated()), id: \.offset) { i, s in
            LineMark(x: .value("t", i), y: .value("X", s.userAccX))
                .foregroundStyle(by: .value("Axis", "X"))
            LineMark(x: .value("t", i), y: .value("Y", s.userAccY))
                .foregroundStyle(by: .value("Axis", "Y"))
            LineMark(x: .value("t", i), y: .value("Z", s.userAccZ))
                .foregroundStyle(by: .value("Axis", "Z"))

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
                .foregroundStyle(by: .value("Axis", "X"))
            LineMark(x: .value("t", i), y: .value("Y", s.rotationRateY))
                .foregroundStyle(by: .value("Axis", "Y"))
            LineMark(x: .value("t", i), y: .value("Z", s.rotationRateZ))
                .foregroundStyle(by: .value("Axis", "Z"))

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
                .foregroundStyle(by: .value("Axis", "Roll"))
            LineMark(x: .value("t", i), y: .value("Pitch", s.attitudePitch))
                .foregroundStyle(by: .value("Axis", "Pitch"))
            LineMark(x: .value("t", i), y: .value("Yaw", s.attitudeYaw))
                .foregroundStyle(by: .value("Axis", "Yaw"))

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
