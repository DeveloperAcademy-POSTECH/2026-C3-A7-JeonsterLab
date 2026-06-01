//
//  DatasetExportOptions.swift
//  JeonstarLab Mac
//

import Foundation

struct DatasetExportOptions: Equatable {
    var userInfoColumns: Set<DatasetUserInfoColumn> = Set(DatasetUserInfoColumn.defaultSelected)
    var motionColumns: Set<DatasetMotionColumn> = Set(DatasetMotionColumn.defaultSelected)

    static let `default` = DatasetExportOptions()
    private static let storageKey = "JeonstarLab.lastDatasetExportOptions"

    static func lastSaved(defaults: UserDefaults = .standard) -> DatasetExportOptions {
        guard let data = defaults.data(forKey: storageKey),
              let payload = try? JSONDecoder().decode(StoragePayload.self, from: data) else {
            return .default
        }
        return DatasetExportOptions(
            userInfoColumns: Set(payload.userInfoColumns.compactMap(DatasetUserInfoColumn.init(rawValue:))),
            motionColumns: Set(payload.motionColumns.compactMap(DatasetMotionColumn.init(rawValue:)))
        )
    }

    func saveAsLastUsed(defaults: UserDefaults = .standard) {
        let payload = StoragePayload(
            userInfoColumns: userInfoColumns.map(\.rawValue),
            motionColumns: motionColumns.map(\.rawValue)
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private struct StoragePayload: Codable {
        let userInfoColumns: [String]
        let motionColumns: [String]
    }
}

enum DatasetRequiredColumn: String, CaseIterable, Identifiable {
    case snapID
    case sampleIndex
    case label

    var id: String { rawValue }
    var header: String { rawValue }
}

enum DatasetUserInfoColumn: String, CaseIterable, Identifiable {
    case userNickname
    case userGender
    case userAgeGroup
    case userHeightCM
    case userDominantHand
    case userSkillLevel
    case userMemo

    var id: String { rawValue }
    var header: String { rawValue }

    var displayName: String {
        switch self {
        case .userNickname: return "이름(닉네임)"
        case .userGender: return "성별"
        case .userAgeGroup: return "연령대"
        case .userHeightCM: return "키(cm)"
        case .userDominantHand: return "주 사용 손"
        case .userSkillLevel: return "숙련도"
        case .userMemo: return "메모"
        }
    }

    static let defaultSelected: [DatasetUserInfoColumn] = [
        .userNickname,
        .userGender,
        .userAgeGroup,
        .userHeightCM,
        .userDominantHand,
        .userSkillLevel,
        .userMemo
    ]
}

enum DatasetMotionColumn: String, CaseIterable, Identifiable {
    case relativeTime
    case timestamp
    case attitudeRoll
    case attitudePitch
    case attitudeYaw
    case rotationRateX
    case rotationRateY
    case rotationRateZ
    case gravityX
    case gravityY
    case gravityZ
    case userAccX
    case userAccY
    case userAccZ

    var id: String { rawValue }
    var header: String { rawValue }
    var displayName: String { rawValue }

    static let defaultSelected: [DatasetMotionColumn] = allCases
}
