//
//  RecordingParticipantInfo.swift
//  JeonstarLab Mac
//

import Foundation

struct RecordingParticipantInfo: Codable, Equatable {
    var nameOrNickname: String
    var gender: ParticipantGenderOption
    var ageGroup: ParticipantAgeGroupOption
    var heightCM: String
    var dominantHand: ParticipantDominantHandOption
    var skillLevel: ParticipantSkillLevelOption
    var memo: String

    init(
        nameOrNickname: String,
        gender: ParticipantGenderOption,
        ageGroup: ParticipantAgeGroupOption,
        heightCM: String,
        dominantHand: ParticipantDominantHandOption = .unspecified,
        skillLevel: ParticipantSkillLevelOption,
        memo: String
    ) {
        self.nameOrNickname = nameOrNickname
        self.gender = gender
        self.ageGroup = ageGroup
        self.heightCM = heightCM
        self.dominantHand = dominantHand
        self.skillLevel = skillLevel
        self.memo = memo
    }

    static let empty = RecordingParticipantInfo(
        nameOrNickname: "",
        gender: .unspecified,
        ageGroup: .unspecified,
        heightCM: "",
        dominantHand: .unspecified,
        skillLevel: .unspecified,
        memo: ""
    )

    var exportDictionary: [String: String] {
        [
            "participantNameOrNickname": nameOrNickname,
            "participantGender": gender.rawValue,
            "participantAgeGroup": ageGroup.rawValue,
            "participantHeightCM": heightCM,
            "participantDominantHand": dominantHand.rawValue,
            "participantSkillLevel": skillLevel.rawValue,
            "participantMemo": memo
        ]
    }

    enum CodingKeys: String, CodingKey {
        case nameOrNickname
        case gender
        case ageGroup
        case heightCM
        case dominantHand
        case skillLevel
        case memo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nameOrNickname = try container.decodeIfPresent(String.self, forKey: .nameOrNickname) ?? ""
        gender = try container.decodeIfPresent(ParticipantGenderOption.self, forKey: .gender) ?? .unspecified
        ageGroup = try container.decodeIfPresent(ParticipantAgeGroupOption.self, forKey: .ageGroup) ?? .unspecified
        heightCM = try container.decodeIfPresent(String.self, forKey: .heightCM) ?? ""
        dominantHand = try container.decodeIfPresent(ParticipantDominantHandOption.self, forKey: .dominantHand) ?? .unspecified
        skillLevel = try container.decodeIfPresent(ParticipantSkillLevelOption.self, forKey: .skillLevel) ?? .unspecified
        memo = try container.decodeIfPresent(String.self, forKey: .memo) ?? ""
    }
}

enum ParticipantGenderOption: String, Codable, CaseIterable, Identifiable {
    case unspecified
    case male
    case female

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unspecified: return "Not set"
        case .male: return "Male"
        case .female: return "Female"
        }
    }
}

enum ParticipantAgeGroupOption: String, Codable, CaseIterable, Identifiable {
    case unspecified
    case under10
    case teens
    case twenties
    case thirties
    case forties
    case fifties
    case sixtiesPlus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unspecified: return "Not set"
        case .under10: return "Under 10"
        case .teens: return "10–19"
        case .twenties: return "20–29"
        case .thirties: return "30–39"
        case .forties: return "40–49"
        case .fifties: return "50–59"
        case .sixtiesPlus: return "60+"
        }
    }
}

enum ParticipantDominantHandOption: String, Codable, CaseIterable, Identifiable {
    case unspecified
    case left
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unspecified: return "Not set"
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

enum ParticipantSkillLevelOption: String, Codable, CaseIterable, Identifiable {
    case unspecified
    case beginner
    case intermediate
    case skilled
    case expert

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unspecified: return "Not set"
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .skilled: return "Skilled"
        case .expert: return "Expert"
        }
    }
}
