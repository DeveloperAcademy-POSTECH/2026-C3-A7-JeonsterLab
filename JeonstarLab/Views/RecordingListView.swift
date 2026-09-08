//
//  RecordingListView.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import SwiftUI

struct RecordingListView: View {

    @State var viewModel:        RecordingListViewModel
    @State var watchControlVM:   WatchControlViewModel

    @State private var isShowingConnectionSettings = false

    var body: some View {
        List {
            watchControlSection

            if viewModel.recordings.isEmpty {
                ContentUnavailableView(
                    "No Recordings",
                    systemImage: "waveform.slash",
                    description: Text("Start a recording on your Watch or use the button below.")
                )
            } else {
                ForEach(viewModel.recordings) { session in
                    NavigationLink(value: session) {
                        RecordingRowView(session: session)
                    }
                }
                .onDelete { offsets in
                    for i in offsets {
                        viewModel.delete(sessionID: viewModel.recordings[i].id)
                    }
                }
            }
        }
        .navigationTitle("Recordings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isShowingConnectionSettings = true } label: {
                    Label("Connection Settings", systemImage: "laptopcomputer")
                }
            }
        }
        .sheet(isPresented: $isShowingConnectionSettings) {
            MacConnectionSettingsView(viewModel: .shared)
        }
        .navigationDestination(for: RecordingSession.self) { session in
            RecordingDetailView(
                viewModel: RecordingDetailViewModel(
                    session:    session,
                    repository: viewModel.repository
                )
            )
        }
        .onAppear {
            viewModel.load()
        }
    }

    // MARK: - Watch 제어 섹션

    private var watchControlSection: some View {
        Section {
            HStack {
                // 연결 상태 표시
                Label(
                    watchControlVM.isReachable ? "Watch Connected" : "Watch Not Connected",
                    systemImage: watchControlVM.isReachable ? "applewatch" : "applewatch.slash"
                )
                .foregroundStyle(watchControlVM.isReachable ? .green : .secondary)
                .font(.subheadline)

                Spacer()

                // 녹화 제어 버튼
                switch watchControlVM.watchState {
                case .recording:
                    Button {
                        watchControlVM.stopRecording()
                    } label: {
                        Label("Stop", systemImage: "stop.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.bordered)
                case .idle, .notConnected:
                    Button {
                        watchControlVM.startRecording()
                    } label: {
                        Label("Record", systemImage: "record.circle")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!watchControlVM.isReachable)
                }
            }
        } header: {
            Text("Watch Controls")
        } footer: {
            if !watchControlVM.isReachable {
                Text("Open the Watch app and keep it near your iPhone.")
                    .font(.caption2)
            }
        }
    }
}

// MARK: - Row

struct RecordingRowView: View {

    let session: RecordingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.headline)
            HStack(spacing: 8) {
                Label(durationText, systemImage: "clock")
                Label("\(session.sampleCount) samples", systemImage: "waveform")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var durationText: String {
        let total = Int(session.duration)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
