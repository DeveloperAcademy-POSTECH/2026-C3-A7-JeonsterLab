import Foundation
import SwiftUI

/// Stable identity with a portable display snapshot. Legacy string values still decode.
nonisolated struct RecordingPackageLabel: Codable, Identifiable, Hashable {
    let rawValue: String
    var displayName: String
    var colorHex: String
    var id: String { rawValue }

    init(id: String = UUID().uuidString, name: String, colorHex: String) {
        rawValue = id
        displayName = name
        self.colorHex = colorHex
    }

    static let unlabeled = Self(id: "unlabeled", name: "Unlabeled", colorHex: "808080")
    static let success = Self(id: "success", name: "Successful Motion", colorHex: "34C759")
    static let failure = Self(id: "failure", name: "Failed Motion", colorHex: "FF453A")
    static let flipped = Self(id: "flipped", name: "Flip Success", colorHex: "0A84FF")
    static let partialFlipped = Self(id: "partialFlipped", name: "Partial Flip", colorHex: "32ADE6")
    static let unflipped = Self(id: "unflipped", name: "Flip Failure", colorHex: "FF9F0A")
    static let loosen = Self(id: "loosen", name: "Loosen", colorHex: "BF5AF2")
    static let idle = Self(id: "idle", name: "Idle", colorHex: "00C7BE")
    static let other = Self(id: "other", name: "Other", colorHex: "808080")
    static let allCases: [Self] = [.unlabeled, .success, .failure, .flipped, .partialFlipped, .unflipped, .loosen, .idle, .other]

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.rawValue == rhs.rawValue }
    func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }

    private enum CodingKeys: String, CodingKey { case id, name, colorHex }
    init(from decoder: Decoder) throws {
        if let raw = try? decoder.singleValueContainer().decode(String.self) {
            let id = ["partialSuccess", "partial"].contains(raw) ? "partialFlipped" : raw
            self = Self.allCases.first { $0.rawValue == id }
                ?? Self(id: id, name: id, colorHex: "808080")
        } else {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.init(id: try c.decode(String.self, forKey: .id),
                      name: try c.decode(String.self, forKey: .name),
                      colorHex: try c.decode(String.self, forKey: .colorHex))
        }
    }
    func encode(to encoder: Encoder) throws {
        // Unmodified built-ins retain the original on-disk representation.
        if let original = Self.allCases.first(where: { $0.id == id }),
           original.displayName == displayName, original.colorHex == colorHex {
            var c = encoder.singleValueContainer()
            try c.encode(rawValue)
        } else {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(rawValue, forKey: .id)
            try c.encode(displayName, forKey: .name)
            try c.encode(colorHex, forKey: .colorHex)
        }
    }

    var color: Color {
        let hex = UInt64(colorHex, radix: 16) ?? 0x808080
        return Color(red: Double((hex >> 16) & 255) / 255,
                     green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
    var backgroundColor: Color { color.opacity(0.5) }
    var chipBackgroundColor: Color { color.opacity(id == "unlabeled" ? 0.12 : 0.22) }
    var chipBorderColor: Color { color.opacity(0.5) }
    var chipForegroundColor: Color { id == "unlabeled" ? .secondary : .primary }

    var datasetValue: String? {
        if id == "unlabeled" { return nil }
        if let original = Self.allCases.first(where: { $0.id == id }), original.displayName == displayName {
            if id == "other" { return nil }
            return id == "partialFlipped" ? "partial_flipped" : id
        }
        return displayName
    }
}
