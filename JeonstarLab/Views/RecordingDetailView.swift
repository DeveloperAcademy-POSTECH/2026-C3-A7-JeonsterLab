import SwiftUI
import MultipeerConnectivity

struct RecordingDetailView: View {
    @State var viewModel: RecordingDetailViewModel
    @State private var exportURLs: [URL] = []
    @State private var isShareSheetPresented = false
    @State private var isExporting = false
    @State private var exportErrorMessage: String?
    @State private var isEditingMemo = false
    @State private var macConnectionViewModel = MacConnectionViewModel.shared

    var body: some View {
        List {
            Section("Recording Information") {
                LabeledContent("Date", value: viewModel.title)
                LabeledContent("Duration", value: viewModel.durationText)
                LabeledContent("Samples", value: viewModel.sampleCountText)
            }

            Section {
                if viewModel.isLoading {
                    ProgressView("Loading motion data…")
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView("Unable to Load Motion", systemImage: "exclamationmark.triangle",
                                           description: Text(error))
                    Button("Try Again") { Task { await viewModel.loadSamples() } }
                } else if viewModel.samples.isEmpty {
                    ContentUnavailableView("No Motion Samples", systemImage: "waveform.slash",
                                           description: Text("This recording has no samples to preview."))
                } else {
                    RecordingMotionPreview(samples: viewModel.samples,
                                           samplingRate: viewModel.currentSession.samplingRate)
                }
            } header: {
                Text("Motion Preview")
            } footer: {
                Text("Review the recording here. Select segments and build labeled datasets on your Mac.")
            }

            notesSection
            transferSection
        }
        .navigationTitle("Recording Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: exportRecording) {
                    if isExporting { ProgressView() }
                    else { Label("Share Original Files", systemImage: "square.and.arrow.up") }
                }
                .disabled(isExporting)
                .accessibilityLabel("Share Original Files")
            }
        }
        .sheet(isPresented: $isShareSheetPresented) { ShareSheet(activityItems: exportURLs) }
        .alert("Export failed", isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { exportErrorMessage = nil }
        } message: {
            Text(exportErrorMessage ?? "An unknown error occurred.")
        }
        .task { await viewModel.loadSamples() }
    }

    private var notesSection: some View {
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

                }

                if let memoErrorMessage = viewModel.memoErrorMessage {
                    Text("Failed to save notes: \(memoErrorMessage)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

    }

    private var transferSection: some View {
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
}
