//
//  MacPeerReceiver.swift
//  JeonstarLab Mac
//

import Foundation
import AppKit
import MultipeerConnectivity

final class MacPeerReceiver: NSObject {
    var onStatusChanged: ((MacReceiverStatus) -> Void)?
    var onConnectedPeerChanged: ((String?) -> Void)?
    var onReceivedFiles: (([URL]) -> Void)?
    var onError: ((String) -> Void)?

    private var isAdvertising = false
    private var isApproving = false
    private let peerID = MCPeerID(displayName: Host.current().localizedName ?? "WatchMotion Editor")
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let fileStore: MacReceivedFileStore

    override init() {
        session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: nil,
            serviceType: MacPeerServiceConfig.serviceType
        )
        fileStore = MacReceivedFileStore()
        super.init()
        session.delegate = self
        advertiser.delegate = self
    }

    func startAdvertising() {
        isAdvertising = true
        advertiser.startAdvertisingPeer()
        onStatusChanged?(.advertising)
    }

    func stopAdvertising() {
        isAdvertising = false
        advertiser.stopAdvertisingPeer()
        session.disconnect()
        onConnectedPeerChanged?(nil)
        onStatusChanged?(.idle)
    }

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        onStatusChanged?(.failed(message))
        onError?(message)
    }
}

extension MacPeerReceiver: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor in
            guard isAdvertising, !isApproving, session.connectedPeers.isEmpty else {
                invitationHandler(false, nil); return
            }
            isApproving = true
            let alert = NSAlert()
            alert.messageText = "Connect to iPhone?"
            alert.informativeText = "\(peerID.displayName) wants to send recordings. Only allow a device you recognize."
            alert.addButton(withTitle: "Allow")
            alert.addButton(withTitle: "Decline")
            NSApp.activate(ignoringOtherApps: true)
            let allowed = alert.runModal() == .alertFirstButtonReturn
            isApproving = false
            invitationHandler(allowed && isAdvertising, allowed && isAdvertising ? session : nil)
        }
    }

    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: Error
    ) {
        handleError(error)
    }
}

extension MacPeerReceiver: MCSessionDelegate {
    func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        Task { @MainActor in
            switch state {
            case .connected:
                onConnectedPeerChanged?(peerID.displayName)
                onStatusChanged?(.connected)
            case .connecting:
                onConnectedPeerChanged?(peerID.displayName)
                onStatusChanged?(.advertising)
            case .notConnected:
                onConnectedPeerChanged?(nil)
                onStatusChanged?(.advertising)
            @unknown default:
                onStatusChanged?(.failed("Unknown connection state."))
            }
        }
    }

    func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID
    ) {}

    func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {
        Task { @MainActor in
            onStatusChanged?(.receiving)
        }
    }

    nonisolated func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {
        // This must run synchronously before MultipeerConnectivity deletes localURL.
        do {
            if let error { throw error }
            guard let localURL else { throw CocoaError(.fileNoSuchFile) }
            let receipt = try fileStore.saveReceivedFile(temporaryURL: localURL, resourceName: resourceName)
            if let files = receipt.completedFiles {
                let ack = try JSONSerialization.data(withJSONObject: [
                    "transferID": receipt.transferID.uuidString, "success": true
                ])
                try session.send(ack, toPeers: [peerID], with: .reliable)
                Task { @MainActor in
                    self.onReceivedFiles?(files)
                    self.onStatusChanged?(.completed)
                }
            }
        } catch {
            if let id = MacReceivedFileStore.transferID(from: resourceName),
                let ack = try? JSONSerialization.data(withJSONObject: [
                    "transferID": id.uuidString, "success": false, "message": error.localizedDescription
                ]) {
                try? session.send(ack, toPeers: [peerID], with: .reliable)
            }
            Task { @MainActor in self.handleError(error) }
        }
    }

}

enum MacPeerServiceConfig {
    static let serviceType = "wm-editor-v1"
}
