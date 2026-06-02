//
//  WatchSessionManager.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import WatchConnectivity
import os

private let logger = Logger(subsystem: "com.iseungjun.Wrist-Motion", category: "WCSession")

@Observable
final class WatchSessionManager: NSObject {

    var state      = WCSessionActivationState.notActivated
    var isRechable = false

    // MARK: - iOS 전용 콜백

    #if os(iOS)
    /// Watch로부터 파일을 수신하면 호출.
    var onFileReceived: ((WCSessionFile) -> Void)?
    #endif

    // MARK: - watchOS 전용 콜백

    #if os(watchOS)
    /// 파일 전송이 완료(성공/실패)되면 호출.
    var onTransferDidFinish: ((Error?) -> Void)?

    /// iPhone이 녹화 파일을 저장한 뒤 ACK를 보내면 호출.
    var onRecordingImportAcknowledged: ((UUID, String?) -> Void)?

    /// iPhone으로부터 녹화 명령을 수신하면 호출.
    var onCommandReceived: ((RecordingCommand) -> Void)?
    #endif

    override init() {
        super.init()
        guard WCSession.isSupported() else {
            fatalError("Watch Connectivity가 지원되지 않는 기기입니다.")
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        state = WCSession.default.activationState
        if let error {
            logger.error("✗ WCSession 활성화 실패: \(error.localizedDescription)")
        } else {
            logger.debug("✔ WCSession 활성화 완료 — state: \(activationState.rawValue)")
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif

    func sessionReachabilityDidChange(_ session: WCSession) {
        isRechable = WCSession.default.isReachable
    }

    // MARK: 파일 수신 (iPhone)

    #if os(iOS)
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let size = (try? FileManager.default.attributesOfItem(atPath: file.fileURL.path)[.size] as? Int) ?? 0
        logger.debug("▶︎ [6] iPhone didReceive — file: \(file.fileURL.lastPathComponent), size: \(size)B, metadata: \(String(describing: file.metadata))")
        onFileReceived?(file)
    }
    #endif

    // MARK: 명령 수신 (Watch)

    #if os(watchOS)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleCommand(from: message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleCommand(from: userInfo)
    }

    private func handleCommand(from dict: [String: Any]) {
        if let type = dict["type"] as? String,
           type == "recordingImportAck",
           let idString = dict["sessionID"] as? String,
           let sessionID = UUID(uuidString: idString) {
            let fileName = dict["fileName"] as? String
            logger.debug("✔ recordingImportAck 수신 — sessionID: \(idString), fileName: \(fileName ?? "nil")")
            onRecordingImportAcknowledged?(sessionID, fileName)
            return
        }

        guard
            let raw     = dict[RecordingCommand.messageKey] as? String,
            let command = RecordingCommand(rawValue: raw)
        else { return }
        onCommandReceived?(command)
    }
    #endif
}

// MARK: - 파일 전송 (Watch → iPhone)

extension WatchSessionManager {

    func sendFile(file: URL, metadata: [String: Any]?) {
        let activationState = WCSession.default.activationState
        #if os(watchOS)
        let isInstalled = WCSession.default.isCompanionAppInstalled
        logger.debug("▶︎ [3b] sendFile 호출 — activation: \(activationState.rawValue), companionAppInstalled: \(isInstalled), file: \(file.lastPathComponent)")
        #endif
        guard activationState == .activated else {
            logger.error("✗ sendFile 중단 — WCSession not activated (state: \(activationState.rawValue))")
            return
        }
        WCSession.default.transferFile(file, metadata: metadata)
        logger.debug("▶︎ [3c] WCSession.transferFile 호출 완료")
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: (any Error)?) {
        #if os(watchOS)
        if let error {
            logger.error("✗ [5] didFinish 전송 실패 — \(error.localizedDescription)")
        } else {
            logger.debug("✔ [5] didFinish 전송 성공 — file: \(fileTransfer.file.fileURL.lastPathComponent)")
        }
        // transport 완료는 iPhone 저장 완료가 아니므로 파일은 ACK 수신 전까지 보관한다.
        onTransferDidFinish?(error)
        #endif
    }
}

// MARK: - 명령 전송 (iPhone → Watch)

#if os(iOS)
extension WatchSessionManager {

    /// Watch에 녹화 명령을 전송.
    /// Watch가 활성 상태면 sendMessage(즉시), 아니면 transferUserInfo(백그라운드)로 폴백.
    func sendCommand(_ command: RecordingCommand) {
        guard WCSession.default.activationState == .activated else { return }
        let message = [RecordingCommand.messageKey: command.rawValue]
        sendMessageOrUserInfo(message)
    }

    func sendRecordingImportAck(sessionID: UUID, fileName: String) {
        guard WCSession.default.activationState == .activated else { return }
        let message: [String: Any] = [
            "type": "recordingImportAck",
            "sessionID": sessionID.uuidString,
            "fileName": fileName
        ]
        sendMessageOrUserInfo(message)
        logger.debug("✔ recordingImportAck 전송 — sessionID: \(sessionID.uuidString), fileName: \(fileName)")
    }

    private func sendMessageOrUserInfo(_ message: [String: Any]) {
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        } else {
            WCSession.default.transferUserInfo(message)
        }
    }
}
#endif
