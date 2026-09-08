//
//  MacConnectionViewModel.swift
//  Wrist Motion
//

import Foundation
import MultipeerConnectivity

@Observable
@MainActor
final class MacConnectionViewModel {
    static let shared = MacConnectionViewModel()

    private let browser = MacPeerBrowser()
    private let transferService = MacTransferService()
    private var searchTimeoutTask: Task<Void, Never>?
    private var autoTransferAttemptedSessionIDs: Set<UUID> = []

    var connectionStatus: MacConnectionStatus = .idle
    var connectedMacName: String?
    var discoveredMacs: [MCPeerID] = []
    var transferStatus: MacTransferStatus = .idle
    private(set) var transferSessionID: UUID?
    var errorMessage: String?
    var isAutomaticTransferEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutomaticTransferEnabled, forKey: Self.autoTransferDefaultsKey)
        }
    }

    private static let autoTransferDefaultsKey = "macAutoTransferEnabled"

    init() {
        isAutomaticTransferEnabled = UserDefaults.standard.bool(forKey: Self.autoTransferDefaultsKey)
        browser.onStatusChanged = { [weak self] status in
            self?.connectionStatus = status
            if status == .disconnected { self?.transferService.cancel() }
            if status == .connected {
                self?.searchTimeoutTask?.cancel()
                self?.discoveredMacs = []
            }
        }
        browser.onConnectedPeerChanged = { [weak self] peerName in
            self?.connectedMacName = peerName
        }
        browser.onDiscoveredPeersChanged = { [weak self] peers in
            self?.discoveredMacs = peers
        }
        browser.onError = { [weak self] message in
            self?.errorMessage = message
        }
    }

    var connectionStatusText: String {
        connectionStatus.displayText
    }

    var connectedMacText: String {
        connectedMacName ?? "No Mac connected"
    }

    var transferStatusText: String {
        transferStatus.displayText
    }

    var guidanceText: String {
        switch connectionStatus {
        case .idle:
            return "Choose Start Receiving in the Mac app first."
        case .searching:
            if discoveredMacs.isEmpty {
                return "Looking for a Mac on the same Wi-Fi network or nearby over Bluetooth."
            } else {
                return "Choose a Mac to connect."
            }
        case .found:
            return "Mac found. Connecting…"
        case .connected:
            return "Mac connected."
        case .disconnected:
            return "Mac disconnected. Check that it is ready to receive, then search again."
        case .failed:
            return "No Mac found. Check local network permissions, Wi-Fi, and Bluetooth."
        }
    }

    var automaticTransferGuidanceText: String {
        "Automatically sends new recordings when they are saved while a Mac is connected."
    }

    var canSendToMac: Bool {
        connectionStatus == .connected && connectedMacName != nil && !isTransferring
    }

    var isTransferring: Bool { transferStatus.isTransferring }

    var canSearch: Bool {
        guard !isTransferring else { return false }
        if case .found = connectionStatus { return false }
        return true
    }

    func transferStatus(for sessionID: UUID) -> MacTransferStatus? {
        transferSessionID == sessionID ? transferStatus : nil
    }

    func startSearching() {
        guard canSearch else { return }
        errorMessage = nil
        transferStatus = .idle
        transferSessionID = nil
        browser.startSearching()
        searchTimeoutTask?.cancel()
        searchTimeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(15))
            } catch {
                return // A cancelled search must not time out the next search.
            }
            await MainActor.run {
                guard let self, self.connectionStatus == .searching else { return }
                self.connectionStatus = .failed("No Mac found.")
                self.errorMessage = "No Mac found. Check local network permissions, Wi-Fi, and Bluetooth."
            }
        }
    }

    func stopSearching() {
        searchTimeoutTask?.cancel()
        browser.stopSearching()
    }

    func selectMac(_ peerID: MCPeerID) {
        browser.invitePeer(peerID)
    }

    func sendRecording(
        session: RecordingSession,
        repository: RecordingRepositoryProtocol
    ) {
        guard canSendToMac else { return }
        errorMessage = nil
        transferSessionID = session.id
        transferService.sendRecording(
            session: session,
            repository: repository,
            browser: browser
        ) { [weak self] status in
            self?.transferStatus = status
            if case .failed(let message) = status {
                self?.errorMessage = message
            }
        }
    }

    func sendRecordingIfAutomaticTransferEnabled(
        session: RecordingSession,
        repository: RecordingRepositoryProtocol
    ) {
        guard isAutomaticTransferEnabled else { return }
        guard canSendToMac else {
            errorMessage = "Automatic transfer paused: no Mac connected."
            return
        }
        guard !autoTransferAttemptedSessionIDs.contains(session.id) else { return }

        autoTransferAttemptedSessionIDs.insert(session.id)
        sendRecording(session: session, repository: repository)
    }
}

enum MacConnectionStatus: Equatable {
    case idle
    case searching
    case found(String)
    case connected
    case disconnected
    case failed(String)

    var displayText: String {
        switch self {
        case .idle:
            return "Ready to Find Mac"
        case .searching:
            return "Searching for Mac"
        case .found(let name):
            return "Connecting to \(name)"
        case .connected:
            return "Mac Connected"
        case .disconnected:
            return "Mac Disconnected"
        case .failed(let message):
            return "Connection failed: \(message)"
        }
    }
}

private extension MacTransferStatus {
    var isTransferring: Bool {
        switch self {
        case .preparing, .sending, .verifying:
            return true
        case .idle, .completed, .failed:
            return false
        }
    }
}
