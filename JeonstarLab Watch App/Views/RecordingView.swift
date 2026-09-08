import SwiftUI

struct RecordingView: View {
  @State var viewModel: RecordingViewModel
  var storage: WatchRecordingStorage

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          WatchRecordingDashboard(state: viewModel.state, sampleCount: storage.bufferCount) {
            switch viewModel.state {
            case .idle, .error: viewModel.startRecording()
            case .recording: viewModel.stopRecording()
            case .transferring: break
            }
          }
          NavigationLink {
            SavedWatchRecordingsView(viewModel: viewModel, storage: storage)
          } label: {
            HStack(spacing: 12) {
              Text("Saved Files")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
              Spacer(minLength: 0)
              Text(storage.retainedFiles.count.formatted())
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.white.opacity(0.12), in: Capsule())
                .fixedSize()
            }
            .font(.caption)
            .padding(.horizontal, 4)
          }
          .buttonStyle(.bordered)
          .accessibilityLabel("Saved on Watch, \(storage.retainedFiles.count) recordings")
          Text("Review on iPhone.\nEdit on Mac.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
      }
      .navigationTitle("WatchMotion")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

/// Presentation only: the elapsed timer uses the actual session start date.
struct WatchRecordingDashboard: View {
  let state: RecordingViewModel.RecordingState
  let sampleCount: Int
  var onAction: () -> Void

  var body: some View {
    VStack(spacing: 6) {
      Label(statusTitle, systemImage: statusSymbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(statusColor)
      switch state {
      case .recording(let startedAt, _):
        Text(startedAt, style: .timer)
          .font(.system(.title, design: .rounded, weight: .semibold))
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.6)
          .accessibilityLabel("Elapsed recording time")
        Text("\(sampleCount.formatted()) samples")
          .font(.caption2)
          .monospacedDigit()
          .foregroundStyle(.secondary)
      case .idle:
        Image(systemName: "waveform")
          .font(.system(size: 32, weight: .medium))
          .foregroundStyle(.red)
          .accessibilityHidden(true)
          .padding(.vertical, 4)
      case .transferring:
        ProgressView().controlSize(.small)
          .accessibilityLabel("Waiting for file transfer")
        Text("Queued for iPhone.\nDelivery may take a moment.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      case .error(let message):
        Text(message)
          .font(.caption2)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
        Text("Check saved files before starting a new recording.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      if !isTransferring {
        Button(action: onAction) {
          Label(actionTitle, systemImage: actionSymbol)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 24)
        }
        .buttonStyle(.borderedProminent)
        .tint(isTransferring ? .gray : .red)
        .disabled(isTransferring)
        .accessibilityHint(isRecording ? "Saves the recording and queues it for iPhone." : "")
      }
    }
    .frame(maxWidth: .infinity)
  }

  private var isRecording: Bool {
    if case .recording = state { return true }
    return false
  }
  private var isTransferring: Bool {
    if case .transferring = state { return true }
    return false
  }
  private var actionTitle: String { isRecording ? "Stop" : isTransferring ? "Sending…" : "Record" }
  private var actionSymbol: String {
    isRecording ? "stop.fill" : isTransferring ? "iphone" : "record.circle"
  }
  private var statusTitle: String {
    switch state {
    case .idle: "Ready to Record"
    case .recording: "Recording"
    case .transferring: "Transfer Pending"
    case .error: "Needs Attention"
    }
  }
  private var statusSymbol: String {
    switch state {
    case .idle: "checkmark.circle"
    case .recording: "record.circle"
    case .transferring: "arrow.up.circle"
    case .error: "exclamationmark.triangle"
    }
  }
  private var statusColor: Color {
    switch state {
    case .idle: .secondary
    case .recording: .red
    case .transferring: .orange
    case .error: .orange
    }
  }
}
