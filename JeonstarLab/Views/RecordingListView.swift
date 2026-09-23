//
//  RecordingListView.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import SwiftUI

struct RecordingListView: View {

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                    description: Text("Start a recording on your Watch or use the Watch controls above.")
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
        .listStyle(.insetGrouped)
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
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout())
            layout {
                // 연결 상태 표시
                Label(
                    watchControlVM.isReachable ? "Watch Connected" : "Watch Not Connected",
                    systemImage: watchControlVM.isReachable ? "applewatch" : "applewatch.slash"
                )
                .foregroundStyle(watchControlVM.isReachable ? .green : .secondary)
                .font(.subheadline)

                if !dynamicTypeSize.isAccessibilitySize { Spacer() }

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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let session: RecordingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.headline)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                Label(durationText, systemImage: "clock")
                Label("\(session.sampleCount) samples", systemImage: "waveform")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var durationText: String {
        guard session.duration.isFinite, (0...2_678_400).contains(session.duration) else { return "—" }
        let total = Int(session.duration)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
