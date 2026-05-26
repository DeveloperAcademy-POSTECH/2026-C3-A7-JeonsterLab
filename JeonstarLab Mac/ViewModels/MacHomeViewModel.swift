//
//  MacHomeViewModel.swift
//  JeonstarLab Mac
//

import AppKit
import Foundation
import SwiftUI

@Observable
final class MacHomeViewModel {
    private let receiver = MacPeerReceiver()
    private let packageLoader = ReceivedRecordingPackageLoader()
    private let fileStore = MacReceivedFileStore()

    var receiverStatus: MacReceiverStatus = .idle
    var connectedPeerName: String?
    var receivedPackages: [ReceivedRecordingPackage] = []
    var selectedPackageID: ReceivedRecordingPackage.ID?
    var errorMessage: String?

    init() {
        reloadPackages()
        receiver.onStatusChanged = { [weak self] status in
            self?.receiverStatus = status
        }
        receiver.onConnectedPeerChanged = { [weak self] peerName in
            self?.connectedPeerName = peerName
        }
        receiver.onReceivedFiles = { [weak self] fileURLs in
            guard let self else { return }
            let folders = Set(fileURLs.map { $0.deletingLastPathComponent() })
            for folder in folders {
                if let package = packageLoader.loadPackage(folderURL: folder) {
                    upsert(package)
                    selectedPackageID = package.id
                }
            }
        }
        receiver.onError = { [weak self] message in
            self?.errorMessage = message
        }
    }

    var statusText: String {
        receiverStatus.displayText
    }

    var connectedPeerText: String {
        connectedPeerName ?? "연결된 iPhone 없음"
    }

    var guidanceText: String {
        switch receiverStatus {
        case .idle:
            return "먼저 [수신 시작]을 눌러 Mac을 수신 대기 상태로 전환하세요."
        case .advertising:
            return "iPhone 앱의 녹화 상세 화면에서 [Mac 찾기]를 눌러주세요."
        case .connected:
            return "iPhone이 연결되었습니다. 이제 iPhone에서 [Mac으로 전송]을 누를 수 있습니다."
        case .receiving:
            return "녹화 파일을 수신하는 중입니다."
        case .completed:
            return "수신이 완료되었습니다."
        case .failed:
            return "수신에 실패했습니다. 권한, Wi-Fi, Bluetooth 상태를 확인하세요."
        }
    }

    var selectedPackage: ReceivedRecordingPackage? {
        guard let selectedPackageID else { return receivedPackages.first }
        return receivedPackages.first { $0.id == selectedPackageID }
    }

    var rootReceivedFolderURL: URL {
        fileStore.rootDirectory
    }

    var isAdvertising: Bool {
        receiverStatus == .advertising
        || receiverStatus == .connected
        || receiverStatus == .receiving
        || receiverStatus == .completed
    }

    func startReceiver() {
        errorMessage = nil
        receiver.startAdvertising()
    }

    func stopReceiver() {
        receiver.stopAdvertising()
    }

    func reloadPackages() {
        receivedPackages = packageLoader.loadPackages(rootURL: rootReceivedFolderURL)
        if selectedPackageID == nil {
            selectedPackageID = receivedPackages.first?.id
        }
    }

    func openReceivedFolder() {
        let folderURL = selectedPackage?.folderURL ?? rootReceivedFolderURL
        try? FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        NSWorkspace.shared.open(folderURL)
    }

    func bindingForSelectedPackage() -> Binding<ReceivedRecordingPackage>? {
        guard let index = receivedPackages.firstIndex(where: { $0.id == selectedPackage?.id }) else {
            return nil
        }

        return Binding(
            get: { self.receivedPackages[index] },
            set: { self.receivedPackages[index] = $0 }
        )
    }

    func saveLabel(for package: ReceivedRecordingPackage) {
        do {
            try packageLoader.saveLabel(package: package)
            upsert(package)
        } catch {
            errorMessage = "라벨 저장 실패: \(error.localizedDescription)"
        }
    }

    private func upsert(_ package: ReceivedRecordingPackage) {
        if let index = receivedPackages.firstIndex(where: { $0.id == package.id }) {
            receivedPackages[index] = package
        } else {
            receivedPackages.insert(package, at: 0)
        }
        receivedPackages.sort { $0.receivedAt > $1.receivedAt }
    }
}

enum MacReceiverStatus: Equatable {
    case idle
    case advertising
    case connected
    case receiving
    case completed
    case failed(String)

    var displayText: String {
        switch self {
        case .idle:
            return "대기 중"
        case .advertising:
            return "수신 대기 중"
        case .connected:
            return "iPhone 연결됨"
        case .receiving:
            return "수신 중"
        case .completed:
            return "수신 완료"
        case .failed(let message):
            return "수신 실패: \(message)"
        }
    }
}
