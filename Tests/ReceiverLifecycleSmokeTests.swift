// Created by 이돈혁

import Foundation
import MultipeerConnectivity

@main
struct ReceiverLifecycleSmokeTests {
    @MainActor static func main() async {
        let receiver = MacPeerReceiver()
        let peer = MCPeerID(displayName: "Regression iPhone")
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        var statuses: [MacReceiverStatus] = []
        receiver.onStatusChanged = { statuses.append($0) }
        receiver.stopAdvertising()
        for state in [MCSessionState.notConnected, .connecting, .connected] {
            receiver.session(session, peer: peer, didChange: state)
        }
        receiver.session(session, didStartReceivingResourceWithName: "late.csv", fromPeer: peer,
                         with: Progress(totalUnitCount: 1))
        // Delegate callbacks enqueue their UI updates on MainActor.
        try? await Task.sleep(for: .milliseconds(100))
        precondition(statuses.count >= 4)
        precondition(statuses.allSatisfy { $0 == .idle }, "Late callbacks must not restart the receiving UI")
        session.disconnect()
        print("PASS: stopped receiver ignores late connection and resource callbacks")
    }
}
