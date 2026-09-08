import Foundation
import MultipeerConnectivity

@MainActor
final class MacTransferService {
    private var transferID: UUID?
    private var handler: ((MacTransferStatus) -> Void)?
    private var timeout: Task<Void, Never>?
    private var allFilesSent = false
    private var acknowledged = false
    private var exportFolder: URL?

    func sendRecording(session: RecordingSession, repository: RecordingRepositoryProtocol,
        browser: MacPeerBrowser, statusHandler: @escaping (MacTransferStatus) -> Void) {
        guard transferID == nil, let peer = browser.connectedPeerID else {
            statusHandler(.failed("No Mac connected, or another transfer is in progress.")); return
        }
        let id = UUID()
        transferID = id
        handler = statusHandler
        acknowledged = false
        allFilesSent = false
        statusHandler(.preparing)
        browser.onTransferAcknowledged = { [weak self] receivedID, success, message in
            guard let self, self.transferID == receivedID else { return }
            if !success { self.finish(.failed(message ?? "Mac could not save the recording.")); return }
            self.acknowledged = true
            if self.allFilesSent { self.finish(.completed) }
        }
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(120)) } catch { return }
            guard self?.transferID == id else { return }
            self?.finish(.failed("Mac did not confirm saving. The original remains on iPhone. Reconnect and retry."))
        }
        do {
            let urls = try RecordingExportService(repository: repository).export(session: session)
            exportFolder = urls.first?.deletingLastPathComponent()
            sendNext(0, urls: urls, id: id, peer: peer, browser: browser)
        } catch { finish(.failed(error.localizedDescription)) }
    }

    func cancel() {
        guard transferID != nil else { return }
        finish(.failed("Connection lost. Your recording remains on iPhone."))
    }

    private func sendNext(_ index: Int, urls: [URL], id: UUID, peer: MCPeerID, browser: MacPeerBrowser) {
        guard transferID == id else { return }
        guard index < urls.count else {
            allFilesSent = true
            if acknowledged { finish(.completed) } else { handler?(.verifying) }
            return
        }
        handler?(.sending(current: index, total: urls.count))
        browser.mcSession.sendResource(at: urls[index],
            withName: id.uuidString + "__" + urls[index].lastPathComponent, toPeer: peer) { [weak self] error in
            Task { @MainActor in
                guard let self, self.transferID == id else { return }
                if let error { self.finish(.failed(error.localizedDescription)); return }
                self.sendNext(index + 1, urls: urls, id: id, peer: peer, browser: browser)
            }
        }
    }

    private func finish(_ status: MacTransferStatus) {
        timeout?.cancel()
        timeout = nil
        transferID = nil
        let notify = handler
        handler = nil
        // Each export has a unique temporary folder; never delete original recordings.
        if let exportFolder { try? FileManager.default.removeItem(at: exportFolder) }
        exportFolder = nil
        notify?(status)
    }
}

enum MacTransferStatus: Equatable {
    case idle
    case preparing
    case sending(current: Int, total: Int)
    case verifying
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
        case .verifying:
            return "Confirming Mac Save"
        case .completed:
            return "Transfer Complete"
        case .failed(let message):
            return "Transfer failed: \(message)"
        }
    }
}
