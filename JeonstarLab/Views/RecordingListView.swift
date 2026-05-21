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

    var body: some View {
        List {
            watchControlSection

            if viewModel.recordings.isEmpty {
                ContentUnavailableView(
                    "녹화 없음",
                    systemImage: "waveform.slash",
                    description: Text("Watch 또는 아래 버튼으로 녹화를 시작하세요.")
                )
            } else {
                ForEach(viewModel.recordings) { session in
                    NavigationLink(value: session) {
                        RecordingRowView(
                            session:   session,
                            labelName: viewModel.labelName(for: session)
                        )
                    }
                }
                .onDelete { offsets in
                    for i in offsets {
                        viewModel.delete(sessionID: viewModel.recordings[i].id)
                    }
                }
            }
        }
        .navigationTitle("녹화 목록")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ActivityLabelManagementView(
                        viewModel: viewModel.makeManagementViewModel()
                    )
                } label: {
                    Image(systemName: "tag")
                }
            }
        }
        .navigationDestination(for: RecordingSession.self) { session in
            RecordingDetailView(
                viewModel: viewModel.makeDetailViewModel(for: session)
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
                Label(
                    watchControlVM.isReachable ? "Watch 연결됨" : "Watch 연결 안 됨",
                    systemImage: watchControlVM.isReachable ? "applewatch" : "applewatch.slash"
                )
                .foregroundStyle(watchControlVM.isReachable ? .green : .secondary)
                .font(.subheadline)

                Spacer()

                switch watchControlVM.watchState {
                case .recording:
                    Button {
                        watchControlVM.stopRecording()
                    } label: {
                        Label("중지", systemImage: "stop.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.bordered)
                case .idle, .notConnected:
                    Button {
                        watchControlVM.startRecording()
                    } label: {
                        Label("녹화", systemImage: "record.circle")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!watchControlVM.isReachable)
                }
            }
        } header: {
            Text("Watch 제어")
        } footer: {
            if !watchControlVM.isReachable {
                Text("Watch 앱을 실행하고 iPhone과 가까이 두세요.")
                    .font(.caption2)
            }
        }
    }
}

// MARK: - Row

struct RecordingRowView: View {

    let session:   RecordingSession
    let labelName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.headline)
            HStack(spacing: 8) {
                Label(durationText, systemImage: "clock")
                Label("\(session.sampleCount)개", systemImage: "waveform")
                if let labelName {
                    Label(labelName, systemImage: "tag.fill")
                        .foregroundStyle(.blue)
                }
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
