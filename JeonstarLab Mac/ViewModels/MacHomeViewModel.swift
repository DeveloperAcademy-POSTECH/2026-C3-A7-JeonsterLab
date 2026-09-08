//
//  MacHomeViewModel.swift
//  JeonstarLab Mac
//

import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@Observable
final class MacHomeViewModel {
    private let receiver = MacPeerReceiver()
    private let packageLoader = ReceivedRecordingPackageLoader()
    private let fileStore = MacReceivedFileStore()
    private let workspaceManager: ReceiverWorkspaceManager
    private var folderStore: SnapFolderStore
    @ObservationIgnored private var labelChangeObserver: NSObjectProtocol?

    var receiverStatus: MacReceiverStatus = .idle
    var connectedPeerName: String?
    var receivedPackages: [ReceivedRecordingPackage] = []
    var snapFolders: [SnapFolder] = []
    var selectedPackageID: ReceivedRecordingPackage.ID?
    var selectedFolderID: SnapFolder.ID?
    var errorMessage: String?
    var projectPackageMessage: String?
    var searchQuery = ""
    var labelCatalog = ProjectLabelCatalog.legacy

    init(workspace: ReceiverWorkspace? = nil) {
        workspaceManager = ReceiverWorkspaceManager(
            defaultRecordingsURL: fileStore.rootDirectory,
            initialWorkspace: workspace
        )
        folderStore = SnapFolderStore(rootURL: workspaceManager.currentWorkspace.foldersRootURL)
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
            switchToDefaultWorkspace()
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
        labelChangeObserver = NotificationCenter.default.addObserver(
            forName: .recordingPackageLabelDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let packagePath = notification.object as? String else { return }
            self?.reloadPackage(atPath: packagePath)
        }
    }

    deinit {
        if let labelChangeObserver {
            NotificationCenter.default.removeObserver(labelChangeObserver)
        }
    }

    var statusText: String {
        receiverStatus.displayText
    }

    var connectedPeerText: String {
        connectedPeerName ?? "No iPhone connected"
    }

    var guidanceText: String {
        switch receiverStatus {
        case .idle:
            return "Start receiving to make this Mac discoverable."
        case .advertising:
            return "Open a recording on your iPhone and find this Mac."
        case .connected:
            return "Your iPhone is connected. Send the recording from your iPhone."
        case .receiving:
            return "Receiving recording files."
        case .completed:
            return "Recording received."
        case .failed:
            return "Transfer failed. Check permissions, Wi-Fi, and Bluetooth."
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

    var filteredReceivedPackages: [ReceivedRecordingPackage] {
        filteredPackages(receivedPackages)
    }

    var filteredPinnedPackages: [ReceivedRecordingPackage] {
        filteredPackages(receivedPackages.filter(\.isPinned))
    }

    var rootReceivedFolderURL: URL {
        workspaceManager.currentWorkspace.recordingsRootURL
    }

    var activeWorkspace: ReceiverWorkspace {
        workspaceManager.currentWorkspace
    }

    var workspaceTitle: String {
        activeWorkspace.displayName
    }

    var workspaceSubtitle: String {
        activeWorkspace.isDefaultLocal
            ? "Local recording workspace"
            : "Imported project workspace"
    }

    var canOpenProjectPackage: Bool {
        activeWorkspace.isDefaultLocal
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
        do { labelCatalog = try ProjectLabelCatalog.load(root: rootReceivedFolderURL) }
        catch {
            labelCatalog = ProjectLabelCatalog(labels: [ProjectLabelDefinition(label: .unlabeled)])
            errorMessage = "Unable to read project labels: \(error.localizedDescription)"
        }
        try? FileManager.default.createDirectory(
            at: rootReceivedFolderURL,
            withIntermediateDirectories: true
        )
        receivedPackages = packageLoader.loadPackages(rootURL: rootReceivedFolderURL)
        if selectedPackageID == nil && selectedFolderID == nil {
            selectedPackageID = receivedPackages.first?.id
        }
        updateAllFolderItemSnapshots()
    }

    func reloadPackage(atPath packagePath: String) {
        let folderURL = URL(fileURLWithPath: packagePath)
        guard folderURL.deletingLastPathComponent().standardizedFileURL == rootReceivedFolderURL.standardizedFileURL,
              let package = packageLoader.loadPackage(folderURL: folderURL) else {
            return
        }
        upsert(package)
        updateFolderItems(for: package)
    }

    func reloadFolders() {
        folderStore = SnapFolderStore(rootURL: activeWorkspace.foldersRootURL)
        let loadedFolders = folderStore.loadFolders()
        let normalizedFolders = normalizedFolderMemberships(loadedFolders)
        snapFolders = normalizedFolders
        if normalizedFolders != loadedFolders {
            saveFolders()
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

    func switchToDefaultWorkspace() {
        workspaceManager.switchToDefaultWorkspace()
        selectedPackageID = nil
        selectedFolderID = nil
        searchQuery = ""
        reloadFolders()
        reloadPackages()
    }

    func deleteReceivedRecording(_ package: ReceivedRecordingPackage) {
        let standardizedRoot = rootReceivedFolderURL.standardizedFileURL
        let standardizedFolder = package.folderURL.standardizedFileURL
        guard standardizedFolder.deletingLastPathComponent() == standardizedRoot,
              standardizedFolder != standardizedRoot else {
            errorMessage = "Delete failed: the recording folder path could not be verified."
            return
        }

        do {
            try FileManager.default.removeItem(at: standardizedFolder)
            receivedPackages.removeAll { $0.id == package.id }
            if selectedPackageID == package.id {
                selectedPackageID = receivedPackages.first?.id
                if selectedPackageID == nil {
                    selectedFolderID = nil
                }
            }
        } catch {
            errorMessage = "Failed to delete recording: \(error.localizedDescription)"
        }
    }

    func hasSourcePackage(for item: SnapFolderItem) -> Bool {
        receivedPackages.contains { $0.folderURL.lastPathComponent == item.packageFolderName }
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
        let baseName = "New Folder"
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
            errorMessage = "Failed to save labels: \(error.localizedDescription)"
        }
    }

    func togglePinPackage(_ package: ReceivedRecordingPackage) {
        guard let index = receivedPackages.firstIndex(where: { $0.id == package.id }) else { return }
        receivedPackages[index].isPinned.toggle()
        saveLabel(for: receivedPackages[index])
    }

    func pinPackage(_ package: ReceivedRecordingPackage) {
        setPinState(true, for: package)
    }

    func unpinPackage(_ package: ReceivedRecordingPackage) {
        setPinState(false, for: package)
    }

    func folderContainingSnap(package: ReceivedRecordingPackage, event: WorkingSnapEvent) -> SnapFolder? {
        snapFolders.first { folder in
            folder.items.contains { item in
                isSameSnap(item, package: package, event: event)
            }
        }
    }

    func addSnap(_ event: WorkingSnapEvent, from package: ReceivedRecordingPackage, to folder: SnapFolder) {
        let currentLabel = package.snapEventLabels[event.snapID]?.label ?? event.label
        guard currentLabel != .unlabeled,
              folderContainingSnap(package: package, event: event) == nil,
              let folderIndex = snapFolders.firstIndex(where: { $0.id == folder.id }) else {
            return
        }

        var labeledEvent = event
        labeledEvent.label = currentLabel
        snapFolders[folderIndex].items.append(folderItem(from: package, event: labeledEvent))
        snapFolders[folderIndex].updatedAt = Date()
        saveFolders()
    }

    func removeSnap(_ event: WorkingSnapEvent, from package: ReceivedRecordingPackage, folder _: SnapFolder) {
        var didChange = false
        for folderIndex in snapFolders.indices {
            let originalCount = snapFolders[folderIndex].items.count
            snapFolders[folderIndex].items.removeAll { item in
                isSameSnap(item, package: package, event: event)
            }
            if snapFolders[folderIndex].items.count != originalCount {
                snapFolders[folderIndex].updatedAt = Date()
                didChange = true
            }
        }

        if didChange {
            saveFolders()
        }
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
            guard let package = receivedPackages.first(where: {
                $0.folderURL.lastPathComponent == item.packageFolderName
            }) else {
                errorMessage = "Source unavailable. The original recording was removed or is not in this workspace."
                return
            }
            selectedPackageID = package.id
            selectedFolderID = nil
        }
    }

    func generateSegments(for folder: SnapFolder) -> String {
        guard let folderIndex = snapFolders.firstIndex(where: { $0.id == folder.id }) else {
            return "Segment generation failed: folder not found."
        }

        var samplesByPackageName: [String: [MotionCSVSample]] = [:]
        var generatedCount = 0
        var skippedCount = 0

        for item in snapFolders[folderIndex].items {
            guard let package = receivedPackages.first(where: { $0.folderURL.lastPathComponent == item.packageFolderName }),
                  let event = package.workingSnapEvents.first(where: { package.isSnapID(item.snapID, matching: $0) }) else {
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
            return "Generated \(generatedCount) segments; skipped \(skippedCount)."
        }
        return "Generated \(generatedCount) segments."
    }

    func exportDataset(for folder: SnapFolder, options: DatasetExportOptions) -> String {
        guard folder.items.isEmpty == false else {
            return "No snaps to export."
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Export CSV Dataset"
        savePanel.nameFieldStringValue = FolderDatasetExportService.defaultFileName(folderName: folder.name)
        savePanel.canCreateDirectories = true
        savePanel.allowedContentTypes = [.commaSeparatedText]

        guard savePanel.runModal() == .OK,
              let outputURL = savePanel.url else {
            return "Export canceled."
        }

        do {
            let packagesForExport = reloadPackagesForExport()
            let report = try FolderDatasetExportService.export(
                folder: folder,
                packages: packagesForExport,
                outputURL: outputURL,
                options: options
            )

            var message = "\(report.summaryText) · \(report.outputURL.lastPathComponent)"
            if report.skippedItemCount > 0 {
                let reasons = report.skippedReasons.prefix(2).joined(separator: " / ")
                if !reasons.isEmpty {
                    message += "\nSkipped items: \(reasons)"
                }
            }
            return message
        } catch {
            return "CSV export failed: \(error.localizedDescription)"
        }
    }

    func exportCreateMLActivityDataset(for folder: SnapFolder) -> String {
        guard folder.items.isEmpty == false else {
            return "No snaps to export."
        }

        let openPanel = NSOpenPanel()
        openPanel.title = "Choose Create ML Export Location"
        openPanel.prompt = "Export"
        openPanel.message = "Creates a \(folder.name) class folder with one CSV file per snap in the selected location."
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false

        guard openPanel.runModal() == .OK,
              let outputDirectoryURL = openPanel.url else {
            return "Export canceled."
        }

        do {
            let packagesForExport = reloadPackagesForExport()
            let report = try CreateMLActivityExporter.export(
                folder: folder,
                packages: packagesForExport,
                destinationDirectoryURL: outputDirectoryURL
            )

            var message = "\(report.summaryText) · \(report.outputDirectoryURL.lastPathComponent)"
            if report.skippedItemCount > 0 {
                let reasons = report.skippedReasons.prefix(2).joined(separator: " / ")
                if !reasons.isEmpty {
                    message += "\nSkipped items: \(reasons)"
                }
            }
            return message
        } catch {
            return "Create ML export failed: \(error.localizedDescription)"
        }
    }

    func exportReceiverProjectPackage() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export WatchMotion Editor Project"
        savePanel.nameFieldStringValue = ReceiverProjectPackageService.defaultFileName()
        savePanel.canCreateDirectories = true
        savePanel.allowedContentTypes = [ProjectExportPreferences.format.contentType]
        savePanel.isExtensionHidden = false

        guard savePanel.runModal() == .OK,
              let outputURL = savePanel.url else {
            return
        }

        do {
            let report = try ReceiverProjectPackageService.exportProject(
                recordingsRootURL: activeWorkspace.recordingsRootURL,
                foldersRootURL: activeWorkspace.foldersRootURL,
                workspaceName: activeWorkspace.displayName,
                folders: snapFolders,
                outputURL: outputURL
            )
            projectPackageMessage = "\(report.message): \(report.recordingCount) recordings, \(report.folderCount) folders\n\(report.outputURL?.lastPathComponent ?? "")"
        } catch {
            errorMessage = "Project export failed: \(error.localizedDescription)"
        }
    }

    func makeProjectWindowRequest() -> ReceiverProjectWindowRequest? {
        let openPanel = NSOpenPanel()
        openPanel.title = "Open WatchMotion Editor Project"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.watchMotionProject, UTType(filenameExtension: "jeonstarlab") ?? .data, .zip]

        guard openPanel.runModal() == .OK,
              let packageURL = openPanel.url else {
            return nil
        }

        do {
            let workspace = try workspaceManager.createProjectWorkspace(packageURL: packageURL)
            projectPackageMessage = "Opened project in a new window.\n\(workspace.displayName)"
            return ReceiverProjectWindowRequest(workspace: workspace)
        } catch {
            errorMessage = "Failed to open project: \(error.localizedDescription)"
            return nil
        }
    }

    private func reloadPackagesForExport() -> [ReceivedRecordingPackage] {
        let loadedPackages = packageLoader.loadPackages(rootURL: rootReceivedFolderURL)
        guard !loadedPackages.isEmpty else {
            return receivedPackages
        }
        receivedPackages = loadedPackages
        updateAllFolderItemSnapshots(shouldSave: false)
        return loadedPackages
    }

    private func upsert(_ package: ReceivedRecordingPackage) {
        if let index = receivedPackages.firstIndex(where: { $0.id == package.id }) {
            receivedPackages[index] = package
        } else {
            receivedPackages.insert(package, at: 0)
        }
        receivedPackages.sort { $0.receivedAt > $1.receivedAt }
    }

    private func setPinState(_ isPinned: Bool, for package: ReceivedRecordingPackage) {
        guard let index = receivedPackages.firstIndex(where: { $0.id == package.id }),
              receivedPackages[index].isPinned != isPinned else {
            return
        }
        receivedPackages[index].isPinned = isPinned
        saveLabel(for: receivedPackages[index])
    }

    private func filteredPackages(_ packages: [ReceivedRecordingPackage]) -> [ReceivedRecordingPackage] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return packages }

        return packages.filter { package in
            searchableText(for: package).localizedCaseInsensitiveContains(query)
        }
    }

    private func searchableText(for package: ReceivedRecordingPackage) -> String {
        [
            package.displayTitle,
            package.participantInfo.nameOrNickname,
            package.participantInfo.gender.displayName,
            package.participantInfo.ageGroup.displayName,
            package.participantInfo.heightCM,
            package.participantInfo.dominantHand.displayName,
            package.participantInfo.skillLevel.displayName,
            package.participantInfo.memo
        ]
        .joined(separator: " ")
    }

    private func updateAllFolderItemSnapshots(shouldSave: Bool = true) {
        guard !snapFolders.isEmpty else { return }
        for package in receivedPackages {
            updateFolderItems(for: package, shouldSave: false)
        }
        snapFolders = normalizedFolderMemberships(snapFolders)
        if shouldSave {
            saveFolders()
        }
    }

    private func updateFolderItems(for package: ReceivedRecordingPackage, shouldSave: Bool = true) {
        var didChange = false

        for folderIndex in snapFolders.indices {
            for itemIndex in snapFolders[folderIndex].items.indices {
                let item = snapFolders[folderIndex].items[itemIndex]
                guard item.packageFolderName == package.folderURL.lastPathComponent,
                      let event = package.workingSnapEvents.first(where: { package.isSnapID(item.snapID, matching: $0) }) else {
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

    private func normalizedFolderMemberships(_ folders: [SnapFolder]) -> [SnapFolder] {
        var seenSnapKeys = Set<String>()
        return folders.map { folder in
            var normalizedFolder = folder
            normalizedFolder.items = folder.items.filter { item in
                let key = snapIdentityKey(
                    packageFolderName: item.packageFolderName,
                    recordingID: item.recordingID,
                    snapID: item.snapID
                )
                return seenSnapKeys.insert(key).inserted
            }
            return normalizedFolder
        }
    }

    private func isSameSnap(
        _ item: SnapFolderItem,
        package: ReceivedRecordingPackage,
        event: WorkingSnapEvent
    ) -> Bool {
        guard item.packageFolderName == package.folderURL.lastPathComponent else { return false }
        return snapIdentityKey(
            packageFolderName: item.packageFolderName,
            recordingID: item.recordingID,
            snapID: item.snapID
        ) == snapIdentityKey(
            packageFolderName: package.folderURL.lastPathComponent,
            recordingID: event.recordingID ?? package.metadata?.recordingID ?? package.snapAnalysis?.recordingID,
            snapID: event.snapID
        ) || package.isSnapID(item.snapID, matching: event)
    }

    private func snapIdentityKey(
        packageFolderName: String,
        recordingID: UUID?,
        snapID: String
    ) -> String {
        "\(packageFolderName)|\(recordingID?.uuidString ?? "no-recording-id")|\(snapID)"
    }

    private func saveFolders() {
        do {
            try folderStore.saveFolders(snapFolders)
        } catch {
            errorMessage = "Failed to save folders: \(error.localizedDescription)"
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
            return "Idle"
        case .advertising:
            return "Ready to Receive"
        case .connected:
            return "iPhone Connected"
        case .receiving:
            return "Receiving"
        case .completed:
            return "Received"
        case .failed(let message):
            return "Transfer failed: \(message)"
        }
    }
}
