//
//  ReceivedRecordingPackageLoader.swift
//  JeonstarLab Mac
//

import Foundation

final class ReceivedRecordingPackageLoader {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func loadPackages(rootURL: URL) -> [ReceivedRecordingPackage] {
        guard let folders = try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return folders
            .filter { $0.hasDirectoryPath }
            .compactMap(loadPackage(folderURL:))
            .sorted { $0.receivedAt > $1.receivedAt }
    }

    func loadPackage(folderURL: URL) -> ReceivedRecordingPackage? {
        let csvURL = existingFile(named: "recording.csv", in: folderURL)
        let metadataURL = existingFile(named: "metadata.json", in: folderURL)
        let snapAnalysisURL = existingFile(named: "snap_analysis.json", in: folderURL)

        guard csvURL != nil || metadataURL != nil || snapAnalysisURL != nil else {
            return nil
        }

        var messages: [String] = []
        let metadata: RecordingExportMetadata?
        if let metadataURL {
            do {
                metadata = try RecordingMetadataJSONParser.parse(url: metadataURL)
            } catch {
                metadata = nil
                messages.append("metadata.json 파싱 실패")
            }
        } else {
            metadata = nil
            messages.append("metadata.json 없음")
        }

        let snapAnalysis: SnapAnalysisExport?
        if let snapAnalysisURL {
            do {
                snapAnalysis = try SnapAnalysisJSONParser.parse(url: snapAnalysisURL)
            } catch {
                snapAnalysis = nil
                messages.append("분석 데이터 파싱 실패")
            }
        } else {
            snapAnalysis = nil
            messages.append("snap_analysis.json 없음")
        }

        if csvURL == nil {
            messages.append("recording.csv 없음")
        }

        let labelPayload = loadLabelPayload(folderURL: folderURL)

        return ReceivedRecordingPackage(
            id: folderURL,
            folderURL: folderURL,
            receivedAt: receivedAt(for: folderURL),
            csvURL: csvURL,
            metadataURL: metadataURL,
            snapAnalysisURL: snapAnalysisURL,
            metadata: metadata,
            snapAnalysis: snapAnalysis,
            displayName: labelPayload?.displayName ?? "",
            label: labelPayload?.label ?? .unlabeled,
            notes: labelPayload?.notes ?? "",
            participantInfo: labelPayload?.participantInfo ?? .empty,
            snapLabels: labelPayload?.snapLabels ?? [:],
            snapEventLabels: labelPayload?.snapEventLabels ?? [:],
            manualSnapEvents: labelPayload?.manualSnapEvents ?? [],
            editedSnapEvents: labelPayload?.editedSnapEvents ?? [:],
            deletedSnapEventIDs: labelPayload?.deletedSnapEventIDs ?? [],
            parseMessages: messages
        )
    }

    func saveLabel(package: ReceivedRecordingPackage) throws {
        let payload = RecordingPackageLabelPayload(
            displayName: package.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : package.displayName,
            label: package.label,
            packageLabel: package.label,
            notes: package.notes,
            participantInfo: package.participantInfo,
            snapLabels: package.snapLabels,
            snapEventLabels: package.snapEventLabels,
            manualSnapEvents: package.manualSnapEvents,
            editedSnapEvents: package.editedSnapEvents,
            deletedSnapEventIDs: package.deletedSnapEventIDs,
            updatedAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        try data.write(
            to: package.folderURL.appendingPathComponent("label.json"),
            options: .atomic
        )
    }

    private func existingFile(named fileName: String, in folderURL: URL) -> URL? {
        let url = folderURL.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    private func loadLabelPayload(folderURL: URL) -> RecordingPackageLabelPayload? {
        let url = folderURL.appendingPathComponent("label.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(RecordingPackageLabelPayload.self, from: data)
    }

    private func receivedAt(for folderURL: URL) -> Date {
        let values = try? folderURL.resourceValues(forKeys: [.creationDateKey])
        return values?.creationDate ?? Date()
    }
}
