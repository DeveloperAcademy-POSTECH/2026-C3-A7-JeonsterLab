//
//  RecordingView.swift
//  Wrist Motion Watch Watch App
//
//  Created by Seungjun Lee on 5/18/26.
//

import SwiftUI

struct RecordingView: View {

    @State var viewModel: RecordingViewModel
    @State private var pendingDeleteFile: RetainedWatchRecordingFile?
    var storage: WatchRecordingStorage

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                statusView
                sampleCountView
                actionButton
                retainedFilesView
            }
            .padding()
        }
        .alert(
            "Delete this saved recording?",
            isPresented: Binding(
                get: { pendingDeleteFile != nil },
                set: { if !$0 { pendingDeleteFile = nil } }
            ),
            presenting: pendingDeleteFile
        ) { file in
            Button("Delete", role: .destructive) {
                storage.deleteRetainedFile(file)
                pendingDeleteFile = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteFile = nil
            }
        } message: { _ in
            Text("This removes the recording from your Watch. If it has not been saved on your iPhone, it cannot be recovered.")
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.state {
        case .idle:
            Text("Ready")
                .foregroundStyle(.secondary)
        case .recording:
            Text("Recording")
                .foregroundStyle(.red)
                .bold()
        case .transferring:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text("Sending…")
            }
            .foregroundStyle(.orange)
        case .error(let message):
            Text(message)
                .foregroundStyle(.red)
                .font(.caption2)
                .multilineTextAlignment(.center)
        }
    }

    private var sampleCountView: some View {
        Text("\(storage.bufferCount) samples")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }

    private var actionButton: some View {
        Button {
            switch viewModel.state {
            case .idle, .error:
                viewModel.startRecording()
            case .recording:
                viewModel.stopRecording()
            case .transferring:
                break
            }
        } label: {
            switch viewModel.state {
            case .recording:
                Label("Stop", systemImage: "stop.circle.fill")
            default:
                Label("Record", systemImage: "record.circle")
            }
        }
        .tint(recordingButtonTint)
        .buttonStyle(.borderedProminent)
        .disabled(isButtonDisabled)
    }

    private var recordingButtonTint: Color {
        if case .recording = viewModel.state { return .red }
        return .green
    }

    private var isButtonDisabled: Bool {
        if case .transferring = viewModel.state { return true }
        return false
    }

    @ViewBuilder
    private var retainedFilesView: some View {
        if !storage.retainedFiles.isEmpty {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Awaiting Confirmation")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(storage.retainedFiles) { file in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.fileName)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(byteCountText(file.byteCount))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 4)

                        Button {
                            viewModel.resendRetainedFile(file)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .disabled(!viewModel.canResendRetainedFile || file.sessionID == nil)
                        .accessibilityLabel("Resend Saved Recording")

                        Button {
                            pendingDeleteFile = file
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .tint(.red)
                        .disabled(!canDeleteRetainedFiles)
                        .accessibilityLabel("Delete Saved Recording")
                    }
                }
            }
        }
    }

    private func byteCountText(_ byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    private var canDeleteRetainedFiles: Bool {
        if case .transferring = viewModel.state { return false }
        return true
    }
}
