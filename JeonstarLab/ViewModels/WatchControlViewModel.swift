//
//  WatchControlViewModel.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation
import WatchConnectivity

@Observable
@MainActor
final class WatchControlViewModel {

    enum WatchState {
        case notConnected
        case idle
        case recording
    }

    private(set) var watchState: WatchState = .idle

    var isReachable: Bool { sessionManager.isRechable }

    private let sessionManager: WatchSessionManager

    init(sessionManager: WatchSessionManager) {
        self.sessionManager = sessionManager
    }

    func startRecording() {
        guard sessionManager.state == .activated else { return }
        sessionManager.sendCommand(.start)
        watchState = .recording
    }

    func stopRecording() {
        guard sessionManager.state == .activated else { return }
        sessionManager.sendCommand(.stop)
        watchState = .idle
    }
}
