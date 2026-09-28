# 2026-09-28 심사 대응 및 재제출 검증

## 확인한 제출 상태

- App Store Connect 앱: `6812215487`, Mac bundle ID: `com.codling.WatchMotionEditor.mac`.
- 현재 거절된 제출: `1.0.1 (20260923)`, 2026-09-25, Guideline 2.1 Information Needed.
- Apple 요청: 실제 Apple 기기에서 현재 앱을 사용하는 영상. 최초 하드웨어 연결부터 전체 동작을 보여 주어야 하며 시뮬레이터 영상으로 대체할 수 없다.
- 기존 2.4.5 네트워크 수신 설명은 심사 노트에 있다. Mac은 iPhone의 MultipeerConnectivity 연결과 파일을 받으므로 `network.server` entitlement를 유지한다.
- 유료 Mac 다운로드로 전환되어 인앱 구매는 없다. iPhone/Watch companion은 무료라는 설명과 실제 설치 경로가 일치해야 한다.
- 이 문서는 제출 준비 기록이다. 촬영, 새 빌드 업로드, Apple 답변 전송, 심사 통과를 증명하지 않는다.

[실제 심사 내역](https://appstoreconnect.apple.com/apps/6812215487/distribution/reviewsubmissions/details/c4ca890a-5a33-4b2b-aab7-8d428ec569ac) · [Apple 심사 가이드라인](https://developer.apple.com/app-store/review/guidelines/)

## 작업 구분

| 이슈 | 완료 증거 |
|---|---|
| #55 실기기 영상 | 실제 Mac/iPhone/Watch 영상, 제출 빌드 일치, 로그인 없이 재생 가능한 URL, 심사 노트 저장 확인 |
| #56 공개 정책 정정 | 사이트 원본 수정·배포 후 `/privacy`의 오래된 IAP/체험 문구 제거 확인 |
| #57 iPhone 개인정보처리방침 | Connection Settings의 Privacy Policy 및 Contact Support 링크 |
| #58 companion 설치 안내 | 심사자가 접근 가능한 설치 URL과 설치·페어링 절차를 실제 기기로 검증 |
| #59 수신 상태 | 중지 후 늦은 연결/리소스 콜백이 idle 상태를 덮어쓰지 않는 회귀 테스트 |
| #60 Create ML 내보내기 | 2개→1개 스냅 재내보내기 시 새 결과 1개, 이전 결과 2개 보존 |
| #61 라벨 손상 | 오류 표시, 쓰기/내보내기 차단, 원본 바이트 보존 및 저장 직전 재검증 |
| #62 CSV 무결성 | 잘못된 헤더·행·비유한 숫자 거부, BOM/CRLF 정상 입력 지원 |
| #63 UI 응답 | CSV/데이터셋/원본 내보내기 worker, 취소 전파, UI heartbeat 및 취소 회귀 테스트 |

## 실기기 촬영 순서 (#55)

1. 제출할 빌드를 확정하고 Mac/iPhone/Watch 모델·OS·앱 버전·빌드 번호를 기록한다. 현재 거절된 빌드와 이번 수정 코드를 혼동하지 않는다.
2. 외부 카메라로 실제 세 기기와 화면을 식별할 수 있게 촬영한다. 계정 비밀번호나 개인 녹화 내용은 노출하지 않는다.
3. 무료 companion 설치와 iPhone–Watch 페어링 상태를 보여 준다. 신규 설치에서 권한 안내를 확인한다.
4. Mac의 수신 시작, iPhone에서 Mac 발견·선택, Mac의 연결 승인까지 처음부터 보여 준다. 같은 로컬 네트워크, Wi-Fi/Bluetooth 및 로컬 네트워크 권한을 확인한다.
5. Watch 앱을 전경에 둔 채 짧은 손목 동작을 기록하고 종료한다. iPhone 목록에 저장되는 것을 보여 준다. 백그라운드 연속 녹화를 지원하는 것처럼 설명하지 않는다.
6. iPhone에서 해당 녹화를 열고 그래프/메모를 확인한 뒤 Send to Mac을 실행한다. Mac 저장 확인까지 완료 상태를 보여 준다.
7. Mac에서 새 녹화를 열고 차트 구간 선택→수동 스냅→라벨/노트→폴더 추가를 보여 준다.
8. CSV와 Create ML 결과를 내보내어 실제 파일을 연다. Create ML은 매번 새 `CreateML-UUID/클래스명/` 경로를 생성한다.
9. 프로젝트 저장/다시 열기, 수신 중지, 연결 재시도를 짧게 확인한다. 결제창이나 체험 제한 없이 편집·내보내기가 동작함을 보여 준다.
10. 영상 URL을 로그아웃 상태에서 열어 재생과 소리/자막을 확인하고, 심사 노트에 영상 URL·기기/빌드·주요 단계의 타임스탬프를 기록한다.

Needs confirmation:
- 실제 제출 대상의 최종 버전/빌드와 설치된 세 기기의 정보.
- 실기기 촬영 파일 및 심사자가 재생 가능한 URL. 현재 영상은 생성하거나 제출하지 않았다.

## companion 재현 안내 (#58)

심사 노트에 다음 사실을 확인하여 기재한다.

- iPhone companion의 실제 App Store 또는 심사자가 접근 가능한 TestFlight 설치 URL, 앱 이름, 버전/빌드.
- Watch 앱 설치 방법과 iPhone 페어링 요구 사항. 최소 iOS 18.6, watchOS 11.6, macOS 15.
- 같은 네트워크에서 연결하고 Mac이 승인하는 순서 및 권한 거부 후 복구 방법.
- Watch 기록→iPhone 수신→Mac 저장 확인→편집→내보내기 순서.
- 샘플 프로젝트는 편집기 확인을 보조할 뿐, 실제 센서/전송 증거나 Apple이 요청한 실기기 영상을 대체하지 않는다.

Needs confirmation:
- companion 설치 URL과 배포 상태. 저장소나 홍보 페이지의 설명만으로 실제 설치 가능성을 입증할 수 없다.

## 공개 정책 정정안 (#56)

대상: <https://watch-motion-editor-site.vercel.app/privacy>

2026-09-28 확인 시 남아 있던 Full Unlock 인앱 구매, 무료 체험 카운터, Keychain의 체험 기록, Restore Purchases 설명은 현재 유료 다운로드 모델과 맞지 않는다. 다음 영문 문단으로 해당 구매/체험 절을 대체하고 갱신 날짜를 실제 배포일로 바꾼다. 다른 절의 개인정보 설명까지 검토 없이 삭제하지 않는다.

> **Purchase model**
>
> WatchMotion Editor for Mac is a paid download from the Mac App Store. The purchase includes the app's editing and export features. The Mac app does not offer in-app purchases, subscriptions, a trial counter, or an in-app Restore Purchases flow. The iPhone and Apple Watch companion apps are free. App Store purchases are handled by Apple under Apple's applicable terms and privacy policy.

배포 후 홈페이지·지원·가이드·정책의 구매 설명을 함께 대조하고, iPhone/Mac의 정책 링크가 같은 최신 페이지를 여는지 확인한다.

Needs confirmation:
- 공개 사이트의 소스 저장소 또는 로컬 경로와 배포 대상. 앱 저장소에는 사이트 소스가 없으며, 이 정정안은 아직 공개 사이트에 반영되지 않았다.

## 자동 검증

Xcode 27.0이 설치된 환경에서 기존 배포 타깃/Swift 언어 모드를 유지한다. 서명 없는 빌드와 단위 회귀 테스트는 실기기 연결이나 App Store 배포 검증을 대신하지 않는다.

```bash
bash Tests/run-receiver-lifecycle-smoke.sh
bash Tests/run-release-ui-smoke.sh
bash Tests/run-dataset-export-smoke.sh
bash Tests/run-project-settings-smoke.sh
bash Tests/run-phone-ui-smoke.sh
```

재제출 전 실제 기기에서는 정책 링크, 권한 거부/재허용, 수신 중지/재시작, 앱 전환으로 Watch 녹화 종료, 큰 파일 내보내기 취소, 손상된 CSV/라벨 오류를 확인한다. #55/#56/#58은 외부 증거가 채워지기 전에는 닫지 않는다.
