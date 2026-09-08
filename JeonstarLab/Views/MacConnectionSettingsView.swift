import SwiftUI
import MultipeerConnectivity

struct MacConnectionSettingsView: View {
    @Bindable var viewModel: MacConnectionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsTutorial = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Help") {
                    Button("Show Tutorial", systemImage: "questionmark.circle") { showsTutorial = true }
                }
                Section("Mac Connection") {
                    MacConnectionControls(viewModel: viewModel)
                }
                Section {
                    Toggle("Auto-send New Recordings", isOn: $viewModel.isAutomaticTransferEnabled)
                } header: {
                    Text("Automatic Transfer")
                } footer: {
                    Text("Sends new Watch recordings while connected. Existing recordings are not sent automatically.")
                }
                Section {
                    DisclosureGroup("Connection Help") {
                        Text("On Mac, choose Start Receiving and approve this iPhone. Keep Wi-Fi and Bluetooth enabled, and allow local network access.")
                            .padding(.vertical, 6)
                    }
                } header: {
                    Text("Before Connecting")
                }
                .font(.callout)
            }
            .navigationTitle("Mac Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .mobileEditorStyle()
        .sheet(isPresented: $showsTutorial) {
            GettingStartedGuideView(audience: .phone) { showsTutorial = false }
                .mobileEditorStyle()
        }
    }
}

/// Shared discovery controls. Connection state is separate from per-recording transfer status.
struct MacConnectionControls: View {
    let viewModel: MacConnectionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "laptopcomputer")
                    .font(.title2)
                    .foregroundStyle(viewModel.connectionStatus == .connected ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.connectionStatus == .connected ? viewModel.connectedMacText : "Connect Your Mac")
                        .font(.headline)
                    Text(viewModel.connectionStatusText)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if viewModel.connectionStatus == .searching { ProgressView() }
            }
            if viewModel.connectionStatus != .connected {
                Text(viewModel.errorMessage ?? viewModel.guidanceText)
                    .font(.caption)
                    .foregroundStyle(viewModel.errorMessage == nil ? Color.secondary : Color.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if viewModel.connectionStatus == .searching {
                ForEach(viewModel.discoveredMacs, id: \.self) { mac in
                    HStack {
                        Text(mac.displayName).font(.callout)
                        Spacer()
                        Button("Connect") { viewModel.selectMac(mac) }
                            .buttonStyle(.borderedProminent)
                    }
                }
                Button("Stop Searching") { viewModel.stopSearching() }
                    .buttonStyle(.bordered)
            } else if viewModel.connectionStatus != .connected {
                Button("Find Mac") { viewModel.startSearching() }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canSearch)
            }
        }
        .padding(.vertical, 4)
    }
}
