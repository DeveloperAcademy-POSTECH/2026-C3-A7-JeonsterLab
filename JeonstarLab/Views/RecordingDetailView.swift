import SwiftUI

struct RecordingDetailView: View {
    @State var viewModel: RecordingDetailViewModel
    @State private var exportURLs: [URL] = []
    @State private var isShareSheetPresented = false
    @State private var isExporting = false
    @State private var exportErrorMessage: String?
    @State private var isEditingMemo = false
    @State private var isShowingConnectionSettings = false
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
        .listStyle(.insetGrouped)
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
        .sheet(isPresented: $isShowingConnectionSettings) {
            MacConnectionSettingsView(viewModel: macConnectionViewModel)
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
                    .buttonStyle(.borderless)
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
                            Image(systemName: "pencil")
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit recording notes")
                    .accessibilityValue(viewModel.savedRecordingMemo)

                }

                if let memoErrorMessage = viewModel.memoErrorMessage {
                    Text("Failed to save notes: \(memoErrorMessage)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

    }

    private var transferSection: some View {
        Section {
            MacConnectionControls(viewModel: macConnectionViewModel)
            if let status = macConnectionViewModel.transferStatus(for: viewModel.currentSession.id) {
                transferStatusView(status)
            } else if macConnectionViewModel.isTransferring {
                Label("Sending another recording…", systemImage: "arrow.up.doc")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Button {
                macConnectionViewModel.sendRecording(
                    session: viewModel.currentSession,
                    repository: viewModel.recordingRepository
                )
            } label: {
                Label("Send to Mac", systemImage: "arrow.up.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!macConnectionViewModel.canSendToMac)
            Button("Connection Settings") { isShowingConnectionSettings = true }
                .font(.callout)
        } header: {
            Text("Transfer to Mac")
        } footer: {
            Text("You can also use the share button to export the original files.")
        }
    }

    private func transferStatusView(_ status: MacTransferStatus) -> some View {
        HStack(spacing: 10) {
            switch status {
            case .preparing, .sending: ProgressView()
            case .completed: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            case .idle: Image(systemName: "arrow.up.doc")
            }
            Text(status.displayText)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
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
