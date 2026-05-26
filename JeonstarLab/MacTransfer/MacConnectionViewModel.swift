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
    private var searchTimeoutTask: Task<Void, Never>?

    var connectionStatus: MacConnectionStatus = .idle
    var connectedMacName: String?
    var transferStatus: MacTransferStatus = .idle
    var errorMessage: String?
    var isAutomaticTransferEnabled = false

    init() {
        browser.onStatusChanged = { [weak self] status in
            self?.connectionStatus = status
            if status == .connected {
                self?.searchTimeoutTask?.cancel()
            }
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

    var guidanceText: String {
        if transferStatus == .completed {
            return "전송이 완료되었습니다."
        }

        switch connectionStatus {
        case .idle:
            return "Mac 앱에서 [수신 시작]을 먼저 눌러주세요."
        case .searching:
            return "같은 Wi-Fi 또는 근처 Bluetooth 환경에서 Mac을 찾는 중입니다."
        case .found:
            return "Mac을 찾았습니다. 연결을 시도하는 중입니다."
        case .connected:
            return "Mac이 연결되었습니다."
        case .disconnected:
            return "Mac 연결이 끊겼습니다. Mac 수신 상태를 확인한 뒤 다시 찾아주세요."
        case .failed:
            return "Mac을 찾지 못했습니다. 로컬 네트워크 권한, Wi-Fi, Bluetooth를 확인하세요."
        }
    }

    var canSendToMac: Bool {
        connectedMacName != nil && transferStatus.isTransferring == false
    }

    func startSearching() {
        errorMessage = nil
        transferStatus = .idle
        browser.startSearching()
        searchTimeoutTask?.cancel()
        searchTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            await MainActor.run {
                guard let self, self.connectionStatus == .searching else { return }
                self.connectionStatus = .failed("Mac을 찾지 못했습니다.")
                self.errorMessage = "Mac을 찾지 못했습니다. 로컬 네트워크 권한, Wi-Fi, Bluetooth를 확인하세요."
            }
        }
    }

    func stopSearching() {
        searchTimeoutTask?.cancel()
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
