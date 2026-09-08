import Foundation
import SwiftUI

struct ProjectLabelDefinition: Codable, Identifiable {
    var label: RecordingPackageLabel
    var shortcut: Int?
    var isArchived = false
    var id: String { label.id }
}

struct ProjectLabelCatalog: Codable {
    static let fileName = "project_labels.json"
    var labels: [ProjectLabelDefinition]
    static var legacy: Self {
        Self(labels: RecordingPackageLabel.allCases.enumerated().map {
            ProjectLabelDefinition(label: $0.element, shortcut: $0.offset + 1)
        })
    }
    var activeLabels: [ProjectLabelDefinition] { labels.filter { !$0.isArchived } }
    func resolve(_ label: RecordingPackageLabel) -> RecordingPackageLabel {
        labels.first { $0.id == label.id }?.label ?? label
    }
    static func load(root: URL) throws -> Self {
        let url = root.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return .legacy }
        let catalog = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        try catalog.validate()
        return catalog
    }
    func save(root: URL) throws {
        try validate()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: root.appendingPathComponent(Self.fileName), options: .atomic)
        NotificationCenter.default.post(name: .projectLabelsDidChange, object: root.standardizedFileURL.path)
    }
    func validate() throws {
        var ids = Set<String>(), names = Set<String>(), shortcuts = Set<Int>()
        for item in labels {
            let name = item.label.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !item.id.isEmpty, ids.insert(item.id).inserted,
                  !name.isEmpty, name.count <= 60,
                  names.insert(name.lowercased()).inserted else {
                throw CatalogError.invalid("Use unique label names (1–60 characters) and IDs.")
            }
            guard item.label.colorHex.range(of: "^[0-9A-Fa-f]{6}$", options: .regularExpression) != nil else {
                throw CatalogError.invalid("Use a six-digit color, such as FF453A.")
            }
            if let key = item.shortcut {
                guard (1...9).contains(key) else { throw CatalogError.invalid("Shortcuts must be 1–9.") }
                if !item.isArchived && !shortcuts.insert(key).inserted {
                    throw CatalogError.invalid("Visible labels cannot share a shortcut.")
                }
            }
        }
        guard let unlabeled = labels.first(where: { $0.id == "unlabeled" }),
              !unlabeled.isArchived, unlabeled.label.displayName == "Unlabeled" else {
            throw CatalogError.invalid("Keep the Unlabeled entry available.")
        }
    }
    enum CatalogError: LocalizedError {
        case invalid(String)
        var errorDescription: String? { if case .invalid(let message) = self { message } else { nil } }
    }
}

extension Notification.Name {
    static let projectLabelsDidChange = Notification.Name("WatchMotionEditor.projectLabelsDidChange")
}

private struct ProjectLabelOptionsKey: EnvironmentKey {
    static let defaultValue = ProjectLabelCatalog.legacy.activeLabels
}
extension EnvironmentValues {
    var projectLabelOptions: [ProjectLabelDefinition] {
        get { self[ProjectLabelOptionsKey.self] }
        set { self[ProjectLabelOptionsKey.self] = newValue }
    }
}

struct ProjectSettingsRequest: Codable, Hashable {
    let recordingsPath: String
    let title: String
}
