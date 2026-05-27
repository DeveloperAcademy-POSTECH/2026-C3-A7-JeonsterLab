//
//  MacPeerReceiver.swift
//  JeonstarLab Mac
//

import Foundation
import MultipeerConnectivity

final class MacPeerReceiver: NSObject {
    var onStatusChanged: ((MacReceiverStatus) -> Void)?
    var onConnectedPeerChanged: ((String?) -> Void)?
    var onReceivedFiles: (([URL]) -> Void)?
    var onError: ((String) -> Void)?

    private let peerID = MCPeerID(displayName: Host.current().localizedName ?? "JeonstarLab Mac")
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
        advertiser.startAdvertisingPeer()
        onStatusChanged?(.advertising)
    }

    func stopAdvertising() {
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
        invitationHandler(true, session)
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
    ) {
        Task { @MainActor in
            onStatusChanged?(.receiving)
        }
    }

    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {
        Task { @MainActor in
            if let error {
                handleError(error)
                return
            }

            guard let localURL else {
                let message = "수신 파일 위치를 찾을 수 없습니다."
                onStatusChanged?(.failed(message))
                onError?(message)
                return
            }

            do {
                let savedURL = try fileStore.saveReceivedFile(
                    temporaryURL: localURL,
                    resourceName: resourceName
                )
                onReceivedFiles?([savedURL])
                onStatusChanged?(.completed)
            } catch {
                handleError(error)
            }
        }
    }
}

enum MacPeerServiceConfig {
    static let serviceType = "jeonstar-data"
}
