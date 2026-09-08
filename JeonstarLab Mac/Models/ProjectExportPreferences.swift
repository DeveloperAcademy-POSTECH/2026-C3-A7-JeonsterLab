import Foundation
import UniformTypeIdentifiers

nonisolated enum ProjectArchiveFormat: String, CaseIterable, Identifiable {
    case watchmotion, zip
    var id: String { rawValue }
    var title: String { self == .watchmotion ? "WatchMotion Project (.watchmotion)" : "ZIP Archive (.zip)" }
    var contentType: UTType { self == .watchmotion ? .watchMotionProject : .zip }
}

extension UTType {
    nonisolated static let watchMotionProject = UTType(exportedAs: "com.Jeonster.WatchMotionEditor.project", conformingTo: .zip)
}

nonisolated enum ProjectExportPreferences {
    static let nameKey = "WatchMotionEditor.projectExportName"
    static let formatKey = "WatchMotionEditor.projectExportFormat"
    static let timestampKey = "WatchMotionEditor.projectExportTimestamp"
    static let defaultName = "WatchMotion_Project"
    static var format: ProjectArchiveFormat {
        ProjectArchiveFormat(rawValue: UserDefaults.standard.string(forKey: formatKey) ?? "") ?? .watchmotion
    }
    static func safeName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:\0").union(.controlCharacters)
        let cleaned = value.components(separatedBy: invalid).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return cleaned.isEmpty ? defaultName : String(cleaned.prefix(100))
    }
    static func fileName(date: Date = Date(), defaults: UserDefaults = .standard) -> String {
        let name = safeName(defaults.string(forKey: nameKey) ?? defaultName)
        let format = ProjectArchiveFormat(rawValue: defaults.string(forKey: formatKey) ?? "") ?? .watchmotion
        let includeDate = defaults.object(forKey: timestampKey) == nil || defaults.bool(forKey: timestampKey)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return name + (includeDate ? "_" + formatter.string(from: date) : "") + "." + format.rawValue
    }
}
