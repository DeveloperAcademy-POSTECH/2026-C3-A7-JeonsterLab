//
//  RecordingView.swift
//  Wrist Motion Watch Watch App
//
//  Created by Seungjun Lee on 5/18/26.
//

import SwiftUI

struct RecordingView: View {

    @State var viewModel: RecordingViewModel
    var storage: WatchRecordingStorage

    var body: some View {
        VStack(spacing: 12) {
            statusView
            sampleCountView
            actionButton
        }
        .padding()
    }

    // MARK: - Subviews

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.state {
        case .idle:
            Text("준비")
                .foregroundStyle(.secondary)
        case .recording:
            Text("녹화 중")
                .foregroundStyle(.red)
                .bold()
        case .transferring:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text("전송 중…")
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
                Label("중지", systemImage: "stop.circle.fill")
            default:
                Label("녹화", systemImage: "record.circle")
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
}
