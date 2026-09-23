import Foundation

/// Each transfer owns an isolated staging folder. Only a complete validated set
/// becomes visible to the recording loader.
final class MacReceivedFileStore: @unchecked Sendable {
    struct Receipt: Sendable {
        let transferID: UUID
        let completedFiles: [URL]?
    }
    nonisolated(unsafe) private let fileManager: FileManager
    private let directory: URL
    private let lock = NSLock()
    nonisolated private static let names: Set<String> = ["recording.csv", "metadata.json", "snap_analysis.json"]

    init(fileManager: FileManager = .default, directory: URL? = nil) {
        self.fileManager = fileManager
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let legacy = documents.appendingPathComponent("JeonstarLab/ReceivedRecordings", isDirectory: true)
        self.directory = directory ?? (fileManager.fileExists(atPath: legacy.path) ? legacy :
            documents.appendingPathComponent("WatchMotion Editor/ReceivedRecordings", isDirectory: true))
    }

    nonisolated var rootDirectory: URL { directory }

    nonisolated static func transferID(from name: String) -> UUID? {
        guard name.count > 38 else { return nil }
        return UUID(uuidString: String(name.prefix(36)))
    }

    nonisolated func saveReceivedFile(temporaryURL: URL, resourceName: String) throws -> Receipt {
        lock.lock()
        defer { lock.unlock() }
        guard let id = Self.transferID(from: resourceName),
            resourceName.dropFirst(36).hasPrefix("__") else { throw invalid("Invalid transfer identifier.") }
        let name = String(resourceName.dropFirst(38))
        guard Self.names.contains(name) else { throw invalid("Unsupported recording file.") }
        let values = try temporaryURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        let limit = name == "recording.csv" ? 256 * 1024 * 1024 : 16 * 1024 * 1024
        guard values.isRegularFile == true, values.isSymbolicLink != true,
            let size = values.fileSize, size > 0, size <= limit else { throw invalid("Recording file is empty or too large.") }
        let final = directory.appendingPathComponent(id.uuidString, isDirectory: true)
        if fileManager.fileExists(atPath: final.path) {
            return Receipt(transferID: id, completedFiles: Self.names.sorted().map { final.appendingPathComponent($0) })
        }
        let staging = directory.appendingPathComponent(".incoming", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        let data = try Data(contentsOf: temporaryURL, options: .mappedIfSafe)
        if name.hasSuffix(".json") {
            guard (try JSONSerialization.jsonObject(with: data)) is [String: Any] else { throw invalid("Invalid recording metadata.") }
        } else {
            guard let header = String(data: data.prefix(1024), encoding: .utf8)?.components(separatedBy: "\n").first,
                header.contains("timestamp"), header.contains("userAccX") else { throw invalid("Unsupported CSV columns.") }
        }
        try data.write(to: staging.appendingPathComponent(name), options: .atomic)
        guard Self.names.allSatisfy({ fileManager.fileExists(atPath: staging.appendingPathComponent($0).path) }) else {
            return Receipt(transferID: id, completedFiles: nil)
        }
        let metadata = try JSONSerialization.jsonObject(with: Data(contentsOf: staging.appendingPathComponent("metadata.json"))) as? [String: Any]
        let analysis = try JSONSerialization.jsonObject(with: Data(contentsOf: staging.appendingPathComponent("snap_analysis.json"))) as? [String: Any]
        let csv = try Data(contentsOf: staging.appendingPathComponent("recording.csv"), options: .mappedIfSafe)
        let rowCount = csv.reduce(0) { $0 + ($1 == 10 ? 1 : 0) } - (csv.last == 10 ? 1 : 0)
        guard let recordingID = metadata?["recordingID"] as? String,
            UUID(uuidString: recordingID) != nil,
            analysis?["recordingID"] as? String == recordingID,
            let sampleCount = metadata?["sampleCount"] as? Int, sampleCount > 0,
            sampleCount == rowCount else { throw invalid("The recording files do not match. Retry the transfer.") }
        // Commit as one folder; failed or interrupted batches remain hidden and retryable.
        try fileManager.moveItem(at: staging, to: final)
        return Receipt(transferID: id, completedFiles: Self.names.sorted().map { final.appendingPathComponent($0) })
    }

    nonisolated private func invalid(_ message: String) -> NSError {
        NSError(domain: "WatchMotionReceive", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
