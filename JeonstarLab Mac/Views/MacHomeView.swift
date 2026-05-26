//
//  MacHomeView.swift
//  JeonstarLab Mac
//

import SwiftUI

struct MacHomeView: View {
    @Bindable var viewModel: MacHomeViewModel

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 12) {
                Text("JeonstarLab Receiver")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("MacBook 데이터 수신 준비")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("JeonstarLab Receiver")
                        .font(.largeTitle)
                        .fontWeight(.semibold)

                    connectionSection
                    recentFilesSection
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(28)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private var connectionSection: some View {
        sectionCard(title: "Connection Status") {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("상태", value: viewModel.statusText)
                LabeledContent("기기", value: viewModel.connectedPeerText)

                HStack(spacing: 12) {
                    Button("파일 열기") {}
                        .disabled(true)
                    Button("수신 시작") {}
                        .disabled(true)
                }
                .padding(.top, 4)
            }
        }
    }

    private var recentFilesSection: some View {
        sectionCard(title: "Recent Received Files") {
            if viewModel.receivedItems.isEmpty {
                Text("아직 수신된 녹화 데이터가 없습니다.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.receivedItems) { item in
                        HStack {
                            Text(item.fileName)
                            Spacer()
                            Text(item.receivedAt.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    MacHomeView(viewModel: MacHomeViewModel())
}
