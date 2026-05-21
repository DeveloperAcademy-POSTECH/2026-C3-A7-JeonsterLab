//
//  ActivityLabelRepositoryProtocol.swift
//  JeonstarLab Core
//
//  Created by Seungjun Lee on 5/21/26.
//

import Foundation

/// Activity 레이블 카탈로그 저장소 인터페이스.
protocol ActivityLabelRepositoryProtocol: AnyObject {
    /// 등록된 모든 레이블. 생성일 오름차순.
    var labels: [ActivityLabel] { get }

    /// 새 레이블 추가.
    func add(name: String) throws

    /// 레이블 삭제. 녹화에서 해당 레이블 해제는 호출자(UseCase) 책임.
    func delete(labelID: UUID) throws

    /// ID로 레이블 조회.
    func label(for id: UUID) -> ActivityLabel?
}
