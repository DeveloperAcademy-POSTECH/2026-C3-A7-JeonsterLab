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
    var skillLevel: ParticipantSkillLevelOption
    var memo: String

    static let empty = RecordingParticipantInfo(
        nameOrNickname: "",
        gender: .unspecified,
        ageGroup: .unspecified,
        heightCM: "",
        skillLevel: .unspecified,
        memo: ""
    )

    var exportDictionary: [String: String] {
        [
            "participantNameOrNickname": nameOrNickname,
            "participantGender": gender.rawValue,
            "participantAgeGroup": ageGroup.rawValue,
            "participantHeightCM": heightCM,
            "participantSkillLevel": skillLevel.rawValue,
            "participantMemo": memo
        ]
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
