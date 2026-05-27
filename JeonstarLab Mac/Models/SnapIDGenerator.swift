//
//  SnapIDGenerator.swift
//  JeonstarLab Mac
//

import Foundation

enum SnapIDGenerator {
    static func automatic(
        recordingID: UUID?,
        packageFolderName: String,
        eventKey: Int
    ) -> String {
        "auto_\(sourceToken(recordingID: recordingID, packageFolderName: packageFolderName))_\(padded(eventKey))"
    }

    static func manual(
        recordingID: UUID?,
        packageFolderName: String,
        uuid: UUID = UUID()
    ) -> String {
        "manual_\(sourceToken(recordingID: recordingID, packageFolderName: packageFolderName))_\(uuid.uuidString)"
    }

    static func legacyAutomaticIDs(for eventKey: Int) -> [String] {
        [
            "automatic-\(eventKey)",
            "snap_\(padded(eventKey))",
            "snap_\(String(format: "%03d", locale: Locale(identifier: "en_US_POSIX"), eventKey))",
            "snap_\(String(format: "%03d", locale: Locale(identifier: "en_US_POSIX"), eventKey + 1))",
            "event_\(eventKey)"
        ]
    }

    static func isGlobalSnapID(_ value: String) -> Bool {
        value.hasPrefix("auto_") || value.hasPrefix("manual_")
    }

    private static func sourceToken(recordingID: UUID?, packageFolderName: String) -> String {
        if let recordingID {
            return filesystemSafeName(recordingID.uuidString)
        }
        return filesystemSafeName(packageFolderName)
    }

    private static func padded(_ value: Int) -> String {
        String(format: "%04d", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func filesystemSafeName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        })
    }
}
