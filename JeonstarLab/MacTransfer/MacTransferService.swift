//
//  MacTransferService.swift
//  Wrist Motion
//

import Foundation
import MultipeerConnectivity

@MainActor
final class MacTransferService {
    func sendRecording(
        session: RecordingSession,
        repository: RecordingRepositoryProtocol,
        browser: MacPeerBrowser,
        statusHandler: @escaping (MacTransferStatus) -> Void
    ) {
        guard let peerID = browser.connectedPeerID else {
            statusHandler(.failed("No Mac connected."))
            return
        }

        statusHandler(.preparing)

        do {
            let fileURLs = try RecordingExportService(repository: repository)
                .export(session: session)
            try send(fileURLs: fileURLs, to: peerID, browser: browser, statusHandler: statusHandler)
        } catch {
            statusHandler(.failed(error.localizedDescription))
        }
    }

    private func send(
        fileURLs: [URL],
        to peerID: MCPeerID,
        browser: MacPeerBrowser,
        statusHandler: @escaping (MacTransferStatus) -> Void
    ) throws {
        guard !fileURLs.isEmpty else {
            statusHandler(.failed("No files to send."))
            return
        }

        statusHandler(.sending(current: 0, total: fileURLs.count))
        sendNextFile(
            index: 0,
            fileURLs: fileURLs,
            to: peerID,
            browser: browser,
            statusHandler: statusHandler
        )
    }

    private func sendNextFile(
        index: Int,
        fileURLs: [URL],
        to peerID: MCPeerID,
        browser: MacPeerBrowser,
        statusHandler: @escaping (MacTransferStatus) -> Void
    ) {
        guard index < fileURLs.count else {
            statusHandler(.completed)
            return
        }

        let fileURL = fileURLs[index]
        browser.mcSession.sendResource(
            at: fileURL,
            withName: fileURL.lastPathComponent,
            toPeer: peerID
        ) { error in
            Task { @MainActor in
                if let error {
                    statusHandler(.failed(error.localizedDescription))
                    return
                }

                statusHandler(.sending(current: index + 1, total: fileURLs.count))
                self.sendNextFile(
                    index: index + 1,
                    fileURLs: fileURLs,
                    to: peerID,
                    browser: browser,
                    statusHandler: statusHandler
                )
            }
        }
    }
}

enum MacTransferStatus: Equatable {
    case idle
    case preparing
    case sending(current: Int, total: Int)
    case completed
    case failed(String)

    var displayText: String {
        switch self {
        case .idle:
            return "Ready to Send"
        case .preparing:
            return "Preparing Files"
        case .sending(let current, let total):
            return "Sending \(current)/\(total)"
        case .completed:
            return "Transfer Complete"
        case .failed(let message):
            return "Transfer failed: \(message)"
        }
    }
}
