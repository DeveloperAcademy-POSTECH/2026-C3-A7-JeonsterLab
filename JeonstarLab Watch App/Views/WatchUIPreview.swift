#if DEBUG && targetEnvironment(simulator)
  import SwiftUI

  /// Visual fixtures only. No recording, file writes, or transfers are performed.
  struct WatchUIPreview: View {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("--watch-ui-preview") }
    @State private var startedAt = Date().addingTimeInterval(-83)
    private var arguments: [String] { ProcessInfo.processInfo.arguments }

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(spacing: 16) {
            WatchRecordingDashboard(state: previewState, sampleCount: 4150, onAction: {})
            SavedWatchRecordingRow(
              file: RetainedWatchRecordingFile(
                sessionID: UUID(), fileName: "WMTF-12345678-1234-1234-1234-123456789ABC.bin",
                fileURL: URL(fileURLWithPath: "/preview-not-a-real-file.bin"),
                byteCount: 431608, sampleCount: 4150, modifiedAt: Date()),
              canResend: !arguments.contains("sending"), canDelete: !arguments.contains("sending"),
              onResend: {}, onDelete: {}
            )
          }
          .padding(.horizontal, 10)
          .padding(.bottom, 12)
        }
        .navigationTitle("WatchMotion")
        .navigationBarTitleDisplayMode(.inline)
      }
      .dynamicTypeSize(arguments.contains("large-text") ? .accessibility1 : .large)
    }

    private var previewState: RecordingViewModel.RecordingState {
      if arguments.contains("sending") { return .transferring }
      if arguments.contains("error") {
        return .error("The file could not be sent. Open the iPhone app and try again.")
      }
      return .recording(startedAt: startedAt, sessionID: UUID())
    }
  }
#endif
