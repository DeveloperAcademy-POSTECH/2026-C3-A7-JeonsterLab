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
    private let folderStore: SnapFolderStore

    var receiverStatus: MacReceiverStatus = .idle
    var connectedPeerName: String?
    var receivedPackages: [ReceivedRecordingPackage] = []
    var snapFolders: [SnapFolder] = []
    var selectedPackageID: ReceivedRecordingPackage.ID?
    var selectedFolderID: SnapFolder.ID?
    var errorMessage: String?

    init() {
        folderStore = SnapFolderStore(rootURL: fileStore.rootDirectory)
        reloadFolders()
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
                    selectedFolderID = nil
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
        guard let selectedPackageID else {
            return selectedFolderID == nil ? receivedPackages.first : nil
        }
        return receivedPackages.first { $0.id == selectedPackageID }
    }

    var selectedFolder: SnapFolder? {
        guard let selectedFolderID else { return nil }
        return snapFolders.first { $0.id == selectedFolderID }
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
        if selectedPackageID == nil && selectedFolderID == nil {
            selectedPackageID = receivedPackages.first?.id
        }
        updateAllFolderItemSnapshots()
    }

    func reloadFolders() {
        snapFolders = folderStore.loadFolders()
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

    func bindingForSelectedFolder() -> Binding<SnapFolder>? {
        guard let selectedFolderID,
              let index = snapFolders.firstIndex(where: { $0.id == selectedFolderID }) else {
            return nil
        }

        return Binding(
            get: { self.snapFolders[index] },
            set: {
                self.snapFolders[index] = $0
                self.saveFolders()
            }
        )
    }

    func packageSelectionBinding() -> Binding<ReceivedRecordingPackage.ID?> {
        Binding(
            get: { self.selectedPackageID },
            set: { newValue in
                self.selectedPackageID = newValue
                if newValue != nil {
                    self.selectedFolderID = nil
                }
            }
        )
    }

    func selectFolder(_ folder: SnapFolder) {
        selectedFolderID = folder.id
        selectedPackageID = nil
    }

    func selectPackage(id: ReceivedRecordingPackage.ID?) {
        selectedPackageID = id
        if id != nil {
            selectedFolderID = nil
        }
    }

    func addFolder() {
        let baseName = "새 폴더"
        let existingNames = Set(snapFolders.map(\.name))
        var folderName = baseName
        var suffix = 1
        while existingNames.contains(folderName) {
            folderName = "\(baseName) \(suffix)"
            suffix += 1
        }

        let folder = SnapFolder(name: folderName)
        snapFolders.append(folder)
        selectedFolderID = folder.id
        selectedPackageID = nil
        saveFolders()
    }

    func deleteFolder(_ folder: SnapFolder) {
        snapFolders.removeAll { $0.id == folder.id }
        if selectedFolderID == folder.id {
            selectedFolderID = nil
            selectedPackageID = receivedPackages.first?.id
        }
        saveFolders()
    }

    func renameFolder(_ folder: SnapFolder) {
        guard let index = snapFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        snapFolders[index] = folder
        saveFolders()
    }

    func saveLabel(for package: ReceivedRecordingPackage) {
        do {
            try packageLoader.saveLabel(package: package)
            upsert(package)
            updateFolderItems(for: package)
        } catch {
            errorMessage = "라벨 저장 실패: \(error.localizedDescription)"
        }
    }

    func folderNames(for package: ReceivedRecordingPackage, event: WorkingSnapEvent) -> [String] {
        snapFolders
            .filter { folder in
                folder.items.contains {
                    $0.packageFolderName == package.folderURL.lastPathComponent
                    && $0.snapID == event.snapID
                }
            }
            .map(\.name)
    }

    func addSnap(_ event: WorkingSnapEvent, from package: ReceivedRecordingPackage, to folder: SnapFolder) {
        guard let folderIndex = snapFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        let alreadyExists = snapFolders[folderIndex].items.contains {
            $0.packageFolderName == package.folderURL.lastPathComponent && $0.snapID == event.snapID
        }
        guard !alreadyExists else { return }

        snapFolders[folderIndex].items.append(folderItem(from: package, event: event))
        snapFolders[folderIndex].updatedAt = Date()
        saveFolders()
    }

    func removeSnap(_ event: WorkingSnapEvent, from package: ReceivedRecordingPackage, folder: SnapFolder) {
        guard let folderIndex = snapFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        snapFolders[folderIndex].items.removeAll {
            $0.packageFolderName == package.folderURL.lastPathComponent && $0.snapID == event.snapID
        }
        snapFolders[folderIndex].updatedAt = Date()
        saveFolders()
    }

    func removeFolderItem(_ item: SnapFolderItem, from folder: SnapFolder) {
        guard let folderIndex = snapFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        snapFolders[folderIndex].items.removeAll { $0.id == item.id }
        snapFolders[folderIndex].updatedAt = Date()
        saveFolders()
    }

    func openSource(for item: SnapFolderItem) {
        if let package = receivedPackages.first(where: { $0.folderURL.lastPathComponent == item.packageFolderName }) {
            selectedPackageID = package.id
            selectedFolderID = nil
        } else {
            reloadPackages()
            selectedPackageID = receivedPackages.first {
                $0.folderURL.lastPathComponent == item.packageFolderName
            }?.id
            selectedFolderID = nil
        }
    }

    func generateSegments(for folder: SnapFolder) -> String {
        guard let folderIndex = snapFolders.firstIndex(where: { $0.id == folder.id }) else {
            return "세그먼트 생성 실패: 폴더를 찾을 수 없습니다."
        }

        var samplesByPackageName: [String: [MotionCSVSample]] = [:]
        var generatedCount = 0
        var skippedCount = 0

        for item in snapFolders[folderIndex].items {
            guard let package = receivedPackages.first(where: { $0.folderURL.lastPathComponent == item.packageFolderName }),
                  let event = package.workingSnapEvents.first(where: { $0.snapID == item.snapID }) else {
                skippedCount += 1
                continue
            }

            do {
                let samples: [MotionCSVSample]
                if let cachedSamples = samplesByPackageName[item.packageFolderName] {
                    samples = cachedSamples
                } else if let csvURL = package.csvURL {
                    let parsedSamples = try MotionCSVParser.parse(url: csvURL)
                    samplesByPackageName[item.packageFolderName] = parsedSamples
                    samples = parsedSamples
                } else {
                    skippedCount += 1
                    continue
                }

                _ = try SnapSegmentExporter.export(
                    package: package,
                    event: event,
                    samples: samples
                )

                if let itemIndex = snapFolders[folderIndex].items.firstIndex(where: { $0.id == item.id }) {
                    snapFolders[folderIndex].items[itemIndex] = folderItem(
                        from: package,
                        event: event,
                        preserving: item
                    )
                }
                generatedCount += 1
            } catch {
                skippedCount += 1
            }
        }

        snapFolders[folderIndex].updatedAt = Date()
        saveFolders()

        if skippedCount > 0 {
            return "세그먼트 \(generatedCount)개 생성, \(skippedCount)개 건너뜀"
        }
        return "세그먼트 \(generatedCount)개를 생성했습니다."
    }

    private func upsert(_ package: ReceivedRecordingPackage) {
        if let index = receivedPackages.firstIndex(where: { $0.id == package.id }) {
            receivedPackages[index] = package
        } else {
            receivedPackages.insert(package, at: 0)
        }
        receivedPackages.sort { $0.receivedAt > $1.receivedAt }
    }

    private func updateAllFolderItemSnapshots() {
        guard !snapFolders.isEmpty else { return }
        for package in receivedPackages {
            updateFolderItems(for: package, shouldSave: false)
        }
        saveFolders()
    }

    private func updateFolderItems(for package: ReceivedRecordingPackage, shouldSave: Bool = true) {
        let eventsByID = Dictionary(uniqueKeysWithValues: package.workingSnapEvents.map { ($0.snapID, $0) })
        var didChange = false

        for folderIndex in snapFolders.indices {
            for itemIndex in snapFolders[folderIndex].items.indices {
                let item = snapFolders[folderIndex].items[itemIndex]
                guard item.packageFolderName == package.folderURL.lastPathComponent,
                      let event = eventsByID[item.snapID] else {
                    continue
                }

                snapFolders[folderIndex].items[itemIndex] = folderItem(
                    from: package,
                    event: event,
                    preserving: item
                )
                didChange = true
            }
            if didChange {
                snapFolders[folderIndex].updatedAt = Date()
            }
        }

        if didChange && shouldSave {
            saveFolders()
        }
    }

    private func folderItem(
        from package: ReceivedRecordingPackage,
        event: WorkingSnapEvent,
        preserving existingItem: SnapFolderItem? = nil
    ) -> SnapFolderItem {
        let segmentFolderURL = SnapSegmentExporter.segmentFolderURL(
            package: package,
            snapID: event.snapID
        )
        let hasSegment = SnapSegmentExporter.segmentExists(package: package, snapID: event.snapID)
        let segmentFolderName = segmentFolderURL.lastPathComponent

        return SnapFolderItem(
            itemID: existingItem?.itemID ?? UUID(),
            snapID: event.snapID,
            recordingID: event.recordingID ?? package.metadata?.recordingID ?? package.snapAnalysis?.recordingID,
            packageFolderName: package.folderURL.lastPathComponent,
            packageFolderURLString: package.folderURL.path,
            packageDisplayName: package.displayTitle,
            recordingStartedAt: package.metadata?.startedAt,
            sourceType: event.sourceType,
            label: event.label,
            notes: event.notes,
            startTime: event.startTime,
            peakTime: event.peakTime,
            endTime: event.endTime,
            segmentCSVRelativePath: hasSegment ? "segments/\(segmentFolderName)/segment.csv" : nil,
            segmentMetadataRelativePath: hasSegment ? "segments/\(segmentFolderName)/segment_metadata.json" : nil,
            addedAt: existingItem?.addedAt ?? Date()
        )
    }

    private func saveFolders() {
        do {
            try folderStore.saveFolders(snapFolders)
        } catch {
            errorMessage = "폴더 저장 실패: \(error.localizedDescription)"
        }
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
