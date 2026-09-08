import Foundation

enum PendingRecordingInbox {
    nonisolated static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PendingRecordings", isDirectory: true)
    }

    // Copy synchronously before the system removes the received temporary file.
    nonisolated static func stage(_ source: URL, metadata: [String: Any], directory: URL = root) throws -> URL {
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 256 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            let info = try JSONSerialization.data(withJSONObject: metadata)
            try info.write(to: folder.appendingPathComponent("metadata.json"), options: .atomic)
            let destination = folder.appendingPathComponent("recording.bin")
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    nonisolated static func pending(directory: URL = root) -> [(URL, [String: Any])] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return folders.compactMap { folder in
            let file = folder.appendingPathComponent("recording.bin")
            guard FileManager.default.fileExists(atPath: file.path),
                let data = try? Data(contentsOf: folder.appendingPathComponent("metadata.json")),
                let metadata = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
            return (file, metadata)
        }
    }

    nonisolated static func complete(_ file: URL, directory: URL = root) throws {
        let folder = file.deletingLastPathComponent().standardizedFileURL
        guard folder.deletingLastPathComponent() == directory.standardizedFileURL else { return }
        try FileManager.default.removeItem(at: folder)
    }
}
