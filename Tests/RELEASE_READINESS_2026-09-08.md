# v1.0 출시 안정화 검증 — 2026-09-08

브랜치: `final/release-v1.0`. 원격 푸시·배포 서명·업로드·심사 제출은 하지 않았다.
개인정보처리방침 및 프로모션 웹사이트 제작은 사용자 담당으로 유지한다.

## 수정 범위

| 범위 | 반영 내용 |
|---|---|
| iPhone 실행/수신 | 지원하지 않는 WCSession의 강제 종료 제거, DB 초기화 오류의 비파괴 재시도, 시스템 임시 파일을 콜백 안에서 영구 대기함에 복사 |
| 원본 보존 | 재시작 후 대기 파일 재처리, 파일 내용이 다른 중복 ID 거부, DB 저장 실패 롤백, 파일 삭제 실패 시 메타데이터 복구 시도 |
| Watch 저장 | Application Support에 저널 저장, 50샘플 단위 체크포인트, 재시작 시 완전한 샘플 복구, 저장 오류 표시, 빈 파일 재전송 비활성화 |
| Watch 실행 정책 | 앱 목적과 맞지 않는 self-monitoring 확장 실행 및 원격 알림 모드 제거. 앱이 백그라운드로 이동하면 저장 후 중지. 앱 내 안내 반영 |
| Mac 수신 | 최초 연결 승인, 암호화 유지, 전송별 임시 폴더, 파일 이름/형식/크기 및 세 파일의 ID/개수 일치 검사, 원자적 폴더 확정 후 저장 ACK |
| iPhone 전송 | 파일 전송과 Mac 저장 확인 상태 구분, 확인 타임아웃/연결 해제 오류 처리, 원본 녹화 보존 |
| 출시 설정 | iPhone device family만 유지, iOS 앱의 Mac/비전 호환 실행 제외, Mac Sandbox와 파일/네트워크 권한, 세 타겟 개인정보 API 선언 |
| 프로젝트 파일 | 외부 ditto/zipinfo 실행 제거, ZIPFoundation 0.9.20 고정, 경로 탈출·심볼릭 링크·중복 경로·체크섬·압축 해제 크기 검사 |
| 작업 반응성 | Mac 압축/복원을 취소 가능한 백그라운드 작업으로 전환, 기존 내보내기 파일의 원자적 교체, iPhone 녹화 조회를 백그라운드로 분리 |
| 작은 UI 조정 | Watch Record/Stop 아이콘 제거, 설정 도움말 접기, 버튼/설정 제목 축약, 내보내기 파일명 줄 제한과 설정 창 높이 조정 |
| 비정상 데이터 | 유한하지만 과도한 시간 값 및 NaN/무한대 표시 시 정수 변환 크래시 방지 |

### 중요한 동작 변경

- Watch는 이제 **앱을 열어 두고 녹화**한다. 백그라운드 지속 녹화를 지원한다고 홍보하면 안 된다.
- 50 Hz는 요청 샘플링 속도이며 실제 간격은 OS/기기 상태에 따라 달라질 수 있다.
- 강제 종료 직전 아직 체크포인트되지 않은 최대 약 1초 구간은 유실될 수 있다. 저장 공간 고갈, 강제 종료 중 쓰기 실패 등은 실기기 추가 검증 대상이다.
- Bonjour 서비스가 `wm-editor-v1`로 변경되었다. 구형 개발 빌드와 새 빌드를 혼용하지 않는다.
- Mac 샌드박스 밖의 기존 개발 데이터는 자동 삭제/이동하지 않는다. 기존 앱에서 프로젝트를 내보내고 새 앱에서 열어 가져온다.
- 안전 제한: 프로젝트 ZIP 512 MB, 압축 해제 합계 2 GB, 항목 20,000개. 큰 프로젝트는 나누어 내보낸다. 녹화 바이너리/수신 CSV는 256 MB, 수신 JSON은 16 MB로 제한한다.

## 자동 검증 결과

Xcode 26.5 SDK, 로컬 Apple Silicon Mac에서 실행했다.

| 검증 | 결과/실제 범위 |
|---|---|
| iPhone + 포함된 Watch Release archive | 성공, 배포 서명 미적용 |
| Mac Release archive | 성공, 배포 서명 미적용 |
| iPhone + Watch Debug simulator build | 성공 |
| Mac Debug build | 성공 |
| iPhone/Watch 시뮬레이터 시작 | DEBUG 미리보기로 실행 성공, 실행 프로세스 유지 확인. 실제 센서/전송 테스트가 아님 |
| `run-phone-ui-smoke.sh` | 센서 축/단위, 시간 간격, 로드 오류/재시도, 메모, CSV/기존 내보내기, 잘못된 duration 표시 통과 |
| `run-watch-ui-smoke.sh` | 시작/중지/중복 명령/늦은 콜백/재전송/오류 상태, 영구 저널 체크포인트 및 재시작 복구 통과 |
| `run-release-ui-smoke.sh` | Mac CSV 축/구간 분석/빈 구간/내보내기 설정 회귀 통과 |
| `run-phone-inbox-smoke.sh` | 임시 원본 제거 후 대기함 보존, 재시작 검색, 동일 파일 중복 처리, 상충 파일 거부 통과 |
| `run-transfer-storage-smoke.sh` | 순서가 바뀐 3개 파일, 연속 수신 격리, 원자적 완료, 빈 파일/과대 JSON/심볼릭 링크/디렉터리/위험한 이름 거부 통과 |
| `run-project-settings-smoke.sh` | 라벨 ID 보존/검증/프로젝트 분리, watchmotion/zip/기존 jeonstarlab 복원, 원본 CSV 유지, 위험 경로·심볼릭 링크·손상 체크섬 거부, 실패한 내보내기가 기존 파일을 보존하는지 통과 |
| `run-sandbox-smoke.sh` | 실제 sandbox entitlement로 ad-hoc 서명한 Debug 앱에서 컨테이너 내부 저장→압축→복원→CSV 원문 비교 통과 |
| `verify-release-bundles.sh` | Bundle ID/Watch companion/name/version/iPhone family/Watch background mode/세 privacy manifest/라이브러리 고지/Release에서 Debug 전용 검사 코드 제외 확인 통과 |

`AppIntents.framework`를 사용하지 않아 메타데이터 추출을 건너뛴다는 Xcode 경고만 남았다. 이번 최종 빌드에서 Swift 컴파일 오류 및 Swift 경고는 발견되지 않았다.
명령행 회귀 테스트는 프로덕션 모델/서비스를 컴파일하지만 XCTest UI 자동화나 전체 통합 테스트를 대체하지 않는다.

### 재현 명령

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
bash Tests/run-phone-ui-smoke.sh
bash Tests/run-watch-ui-smoke.sh
bash Tests/run-release-ui-smoke.sh
bash Tests/run-phone-inbox-smoke.sh
bash Tests/run-transfer-storage-smoke.sh
bash Tests/run-project-settings-smoke.sh
bash Tests/run-sandbox-smoke.sh
bash Tests/verify-release-bundles.sh /private/tmp/WatchMotionReleasePhone.xcarchive /private/tmp/WatchMotionReleaseMac.xcarchive
```

## 아직 출시 승인으로 간주할 수 없는 부분

1. **실기기 전체 흐름:** Watch 녹화/권한 거부/화면 전환 → iPhone 수신/재실행 → Mac 승인/수신 → 편집/프로젝트 재개/CSV. 연결 끊김, 화면 잠금, 저장 공간 부족, 실패 후 재전송과 원본 보존을 반드시 확인한다. WatchConnectivity 파일 수신은 시뮬레이터로 검증할 수 없다.
2. **직접 UI 검증:** 이번 최종 변경 중 Mac이 잠겨 있어 상호작용 검증을 완료하지 못했다. Mac 최소 창 크기의 라이트/다크 모드, 40 mm Watch, iPhone 큰 글씨, VoiceOver, Open/Save 패널의 컨테이너 외부 폴더 접근을 확인해야 한다. 이전 UI 테스트 기록과 이번 결과를 혼동하지 않는다.
3. **서명 및 서버 검증:** 사용자 계정의 App IDs/Capabilities, provisioning, 배포 인증서, App Store Connect 앱 레코드와 업로드 빌드, privacy report를 확인하고 서명된 archive를 Validate한다. 이 작업에서는 계정 항목을 변경하지 않았다.
4. **메타데이터:** 개인정보처리방침 URL 및 앱 내 접근 경로, 지원/프로모션 페이지, App Privacy 답변, 수출 규정 질문, 스크린샷, 연령 등급, 심사 설명을 최종 준비한다. 추적/개발자 서버 전송이 없는 현재 코드 기준의 manifest를 웹사이트 정책이나 향후 SDK 추가 후에도 그대로 가정하면 안 된다.
5. **필수 기기 안내:** 스토어 설명/튜토리얼/심사 노트에 Apple Watch + 페어링된 iPhone + Mac의 역할과 요구사항을 명시한다. 실제 연동 데모 영상과 심사자가 실행할 순서를 제공한다.
6. **배포 호환성:** 네이티브 iPad family 제외는 iPad의 iPhone 호환 실행을 모두 막는다는 뜻이 아니다. App Store Connect의 최종 호환성/배포 대상을 확인한다. 기존 사용자가 있는 출시 앱의 지원 기기를 줄이는 경우에는 별도 업데이트 정책 확인이 필요하다.

빌드 및 자동 검증 통과는 심사 통과 보장이 아니다. 위 실기기·서명·스토어 항목이 끝나야 최종 출시 후보로 판단할 수 있다.

## 판단에 사용한 공식 자료

- [Apple: App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
- [Apple: Watch 확장 실행 세션의 용도](https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions)
- [Apple: WatchConnectivity 임시 파일 수명](https://developer.apple.com/documentation/watchconnectivity/wcsessionfile/fileurl)
- [Apple: Required Reason API](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
- [Apple: App Review Guidelines](https://developer.apple.com/app-store/review/)
- [Apple: 제출 SDK 요구사항](https://developer.apple.com/app-store/submitting/)
- [ZIPFoundation 공식 저장소](https://github.com/weichsel/ZIPFoundation)
