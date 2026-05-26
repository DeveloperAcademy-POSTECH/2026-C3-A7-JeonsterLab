//
//  MacConnectionViewModel.swift
//  Wrist Motion
//

import Foundation

@Observable
@MainActor
final class MacConnectionViewModel {
    private let browser = MacPeerBrowser()
    private let transferService = MacTransferService()

    var connectionStatus: MacConnectionStatus = .idle
    var connectedMacName: String?
    var transferStatus: MacTransferStatus = .idle
    var errorMessage: String?

    init() {
        browser.onStatusChanged = { [weak self] status in
            self?.connectionStatus = status
        }
        browser.onConnectedPeerChanged = { [weak self] peerName in
            self?.connectedMacName = peerName
        }
        browser.onError = { [weak self] message in
            self?.errorMessage = message
        }
    }

    var connectionStatusText: String {
        connectionStatus.displayText
    }

    var connectedMacText: String {
        connectedMacName ?? "연결된 Mac 없음"
    }

    var transferStatusText: String {
        transferStatus.displayText
    }

    var canSendToMac: Bool {
        connectedMacName != nil && transferStatus.isTransferring == false
    }

    func startSearching() {
        errorMessage = nil
        browser.startSearching()
    }

    func stopSearching() {
        browser.stopSearching()
    }

    func sendRecording(
        session: RecordingSession,
        repository: RecordingRepositoryProtocol
    ) {
        errorMessage = nil
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
            return "Mac 검색 대기"
        case .searching:
            return "Mac 검색 중"
        case .found(let name):
            return "\(name) 연결 시도 중"
        case .connected:
            return "Mac 연결됨"
        case .disconnected:
            return "Mac 연결 끊김"
        case .failed(let message):
            return "연결 실패: \(message)"
        }
    }
}

private extension MacTransferStatus {
    var isTransferring: Bool {
        switch self {
        case .preparing, .sending:
            return true
        case .idle, .completed, .failed:
            return false
        }
    }
}
