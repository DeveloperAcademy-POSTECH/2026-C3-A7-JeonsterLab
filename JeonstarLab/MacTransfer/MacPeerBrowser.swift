//
//  MacPeerBrowser.swift
//  Wrist Motion
//

import Foundation
import MultipeerConnectivity
import UIKit

final class MacPeerBrowser: NSObject {
    var onStatusChanged: ((MacConnectionStatus) -> Void)?
    var onConnectedPeerChanged: ((String?) -> Void)?
    var onError: ((String) -> Void)?

    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private let session: MCSession
    private let browser: MCNearbyServiceBrowser
    private var invitedPeerIDs: Set<MCPeerID> = []

    override init() {
        session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        browser = MCNearbyServiceBrowser(
            peer: peerID,
            serviceType: MacTransferPeerServiceConfig.serviceType
        )
        super.init()
        session.delegate = self
        browser.delegate = self
    }

    var connectedPeerID: MCPeerID? {
        session.connectedPeers.first
    }

    var mcSession: MCSession {
        session
    }

    func startSearching() {
        invitedPeerIDs.removeAll()
        browser.startBrowsingForPeers()
        onStatusChanged?(.searching)
    }

    func stopSearching() {
        browser.stopBrowsingForPeers()
        if connectedPeerID == nil {
            onStatusChanged?(.idle)
        }
    }

    func disconnect() {
        browser.stopBrowsingForPeers()
        session.disconnect()
        invitedPeerIDs.removeAll()
        onConnectedPeerChanged?(nil)
        onStatusChanged?(.disconnected)
    }

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        onStatusChanged?(.failed(message))
        onError?(message)
    }
}

extension MacPeerBrowser: MCNearbyServiceBrowserDelegate {
    func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        Task { @MainActor in
            onStatusChanged?(.found(peerID.displayName))
            guard !invitedPeerIDs.contains(peerID) else { return }
            invitedPeerIDs.insert(peerID)
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 20)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            if connectedPeerID == nil {
                onStatusChanged?(.searching)
            }
        }
    }

    func browser(
        _ browser: MCNearbyServiceBrowser,
        didNotStartBrowsingForPeers error: Error
    ) {
        handleError(error)
    }
}

extension MacPeerBrowser: MCSessionDelegate {
    func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        Task { @MainActor in
            switch state {
            case .connected:
                browser.stopBrowsingForPeers()
                onConnectedPeerChanged?(peerID.displayName)
                onStatusChanged?(.connected)
            case .connecting:
                onConnectedPeerChanged?(peerID.displayName)
                onStatusChanged?(.found(peerID.displayName))
            case .notConnected:
                onConnectedPeerChanged?(nil)
                onStatusChanged?(.disconnected)
            @unknown default:
                onStatusChanged?(.failed("알 수 없는 연결 상태입니다."))
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
    ) {}

    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}

enum MacTransferPeerServiceConfig {
    static let serviceType = "jeonstar-data"
}
