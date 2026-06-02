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
        case .unspecified: return "미입력"
        case .male: return "남성"
        case .female: return "여성"
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
        case .unspecified: return "미입력"
        case .under10: return "10대 미만"
        case .teens: return "10대"
        case .twenties: return "20대"
        case .thirties: return "30대"
        case .forties: return "40대"
        case .fifties: return "50대"
        case .sixtiesPlus: return "60대 이상"
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
        case .unspecified: return "미입력"
        case .left: return "왼손"
        case .right: return "오른손"
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
        case .unspecified: return "미입력"
        case .beginner: return "초보"
        case .intermediate: return "보통"
        case .skilled: return "숙련"
        case .expert: return "전문가"
        }
    }
}
