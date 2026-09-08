import SwiftUI

struct SavedWatchRecordingsView: View {
  var viewModel: RecordingViewModel
  var storage: WatchRecordingStorage
  @State private var pendingDeleteFile: RetainedWatchRecordingFile?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        if storage.retainedFiles.isEmpty {
          Label("No Saved Files", systemImage: "tray")
            .font(.headline)
            .frame(maxWidth: .infinity)
        } else {
          Text("Saved on Watch").font(.headline)
        }
        Text("Files stay here until your iPhone confirms they were imported.")
          .font(.caption2)
          .foregroundStyle(.secondary)
        if let error = storage.lastError {
          Text(error).font(.caption2).foregroundStyle(.orange)
        }
        ForEach(storage.retainedFiles) { file in
          SavedWatchRecordingRow(
            file: file, canResend: viewModel.canResendRetainedFile, canDelete: canDelete,
            onResend: { viewModel.resendRetainedFile(file) },
            onDelete: { pendingDeleteFile = file }
          )
        }
        if case .transferring = viewModel.state {
          Label("Transfer queued for iPhone", systemImage: "arrow.up.circle")
            .font(.caption2).foregroundStyle(.orange)
        } else if case .error(let message) = viewModel.state {
          Text(message).font(.caption2).foregroundStyle(.orange)
        }
      }
      .padding(.horizontal, 10)
      .padding(.bottom, 12)
    }
    .navigationTitle("Saved Files")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { storage.refreshRetainedFiles() }
    .alert(
      "Delete this saved recording?",
      isPresented: Binding(
        get: { pendingDeleteFile != nil },
        set: { if !$0 { pendingDeleteFile = nil } }
      ), presenting: pendingDeleteFile
    ) { file in
      Button("Delete", role: .destructive) {
        guard canDelete else { return }
        storage.deleteRetainedFile(file)
        pendingDeleteFile = nil
      }
      Button("Cancel", role: .cancel) { pendingDeleteFile = nil }
    } message: { _ in
      Text(
        "This removes the recording from your Watch. If it has not been saved on your iPhone, it cannot be recovered."
      )
    }
  }

  private var canDelete: Bool {
    if case .transferring = viewModel.state { return false }
    return true
  }
}

struct SavedWatchRecordingRow: View {
  @State private var isExpanded = false
  let file: RetainedWatchRecordingFile
  let canResend: Bool
  let canDelete: Bool
  var onResend: () -> Void
  var onDelete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        isExpanded.toggle()
      } label: {
        HStack {
          summary
          Spacer(minLength: 2)
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.caption2)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
      .accessibilityHint("Shows file details, resend, and delete actions.")
      if isExpanded {
        VStack(alignment: .leading, spacing: 10) {
          Text(file.fileName)
            .font(.caption2).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Text(ByteCountFormatter.string(fromByteCount: Int64(file.byteCount), countStyle: .file))
            .font(.caption2).foregroundStyle(.secondary)
          Button(action: onResend) {
            Label("Resend", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent).tint(.blue)
          .disabled(!canResend || file.sessionID == nil || file.sampleCount == 0)
          .accessibilityLabel("Resend Saved Recording")
          Button(role: .destructive, action: onDelete) {
            Label("Delete", systemImage: "trash").frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .disabled(!canDelete)
          .accessibilityLabel("Delete Saved Recording")
          if file.sessionID == nil {
            Text("Session ID unavailable. This file cannot be resent.")
              .font(.caption2).foregroundStyle(.orange)
          } else if file.sampleCount == 0 {
            Text("No motion samples were saved. You can delete this empty recording.")
              .font(.caption2).foregroundStyle(.secondary)
          }
        }
        .padding(.top, 6)
      }
    }
    .padding(10)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
  }

  private var summary: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let date = file.modifiedAt {
        Text(date.formatted(date: .abbreviated, time: .shortened))
          .font(.caption.weight(.semibold))
      } else {
        Text("Saved Recording").font(.caption.weight(.semibold))
      }
      Text("\(file.sampleCount.formatted()) samples")
        .font(.caption2).foregroundStyle(.secondary)
    }
  }
}
