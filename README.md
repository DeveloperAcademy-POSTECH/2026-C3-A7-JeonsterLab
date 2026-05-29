# JeonstarLab

> Apple Watch에서 손목 모션 데이터를 기록하고, iPhone을 거쳐 Mac에서 라벨링·분석·데이터셋 내보내기까지 수행하는 iOS / watchOS / macOS 통합 프로젝트입니다.

# 주요 기능

| 구분 | 기능 |
|---|---|
| Apple Watch | Core Motion 기반 손목 모션 기록, WMTF 바이너리 파일 저장, iPhone으로 파일 전송 |
| iPhone | Watch 녹화 수신, SwiftData 메타데이터 저장, 원본 WMTF 파일 보관, CSV/JSON 내보내기 |
| iPhone → Mac | MultipeerConnectivity 기반 수동/선택적 자동 전송 |
| Mac | 수신 녹화 목록, 검색, 고정 기록, 새 창 열기, 사용자 정보 기록 |
| Mac 라벨링 | 자동 스냅 제안, 수동 스냅 생성, 스냅 구간 수정, 라벨/노트 작성, 폴더 분류 |
| Mac 데이터셋 | 스냅 세그먼트 생성, 폴더 기반 단일 CSV 데이터셋 내보내기 |

# 기술 스택

| 구분 | 이름 | 비고 |
|---|---|---|
| UI | SwiftUI | 화면 구현 |
| 모션 추적 | CoreMotion  | 사용자의 모션(가속도, 자이로) 추적|
| 기기 연결 | WatchConnectivity | Watch와 iPhone간의 세션 확인 및 데이터 통신|
| 근거리 전송 | MultipeerConnectivity | iPhone과 Mac 사이의 녹화 데이터 전송 |
| 로컬 저장소 | SwiftData | 구조화된 데이터를 기기 로컬에 영구 저장 |
| Mac 시각화 | Swift Charts | 수신된 모션 CSV의 그래프 표시 |

# 타겟 구성

| 타겟             |                              역할                               | |
| --- | --- | --- |
| JeonstarLab Core             | iOS·watchOS가 공유하는 모델, 프로토콜, WatchConnectivity 매니저 |
| JeonstarLab (iOS)            | iPhone 앱 – Watch 녹화 수신·저장·조회·내보내기·Mac 전송 |
| JeonstarLab Watch App        | Apple Watch 앱 – 센서 녹음·파일 전송 |
| JeonstarLab Mac              | macOS 앱 – 녹화 수신·분석·라벨링·폴더 분류·데이터셋 내보내기 |

# 데이터 흐름

1. Apple Watch가 Core Motion 샘플을 50Hz로 기록합니다.
2. Watch는 WMTF 바이너리 파일을 생성합니다.
   - `[magic UInt32 "WMTF"] [version UInt32] [MotionSample × N]`
3. WatchConnectivity로 iPhone에 녹화 파일을 전송합니다.
4. iPhone은 SwiftData에 녹화 메타데이터를 저장하고, 원본 WMTF 파일은 Documents/Recordings에 보관합니다.
5. iPhone은 선택한 녹화를 `recording.csv`, `metadata.json`, `snap_analysis.json`으로 내보냅니다.
6. iPhone은 내보낸 파일을 공유 시트 또는 MultipeerConnectivity로 Mac에 전달합니다.
7. Mac은 수신 패키지를 `~/Documents/JeonstarLab/ReceivedRecordings/` 아래에 저장합니다.
8. Mac에서 스냅 라벨링, 사용자 정보 기록, 폴더 분류, 데이터셋 CSV 내보내기를 수행합니다.

# 프로젝트 폴더링
```
  각 타겟 내부는 역할(Role) 기준으로 폴더를 나눕니다.                                                         
                  
  Wrist Motion Core/                                                                                          
  ├── Models/       # 순수 값 타입 (MotionSample, RecordingSession, RecordingCommand)
  ├── Protocols/    # 서비스 인터페이스 (Recorder, Storage, Transfer, Repository)                             
  └── (공유 매니저) # WatchSessionManager                                                                     
                                                                                                              
  Wrist Motion/             (iOS)                                                                             
  ├── Views/                                                                                                  
  ├── ViewModels/                                                                                             
  ├── UseCases/
  ├── Storage/      # SwiftData 엔티티 + Repository 구현체                                                    
  ├── Receive/      # WatchConnectivity 파일 수신 브릿지
  ├── Export/       # CSV/JSON 내보내기
  └── MacTransfer/  # iPhone → Mac MultipeerConnectivity 전송
                                                                                                              
  Wrist Motion Watch Watch App/  (watchOS)                                                                    
  ├── Views/                                                                                                  
  ├── ViewModels/ 
  ├── UseCases/
  ├── Manager/      # CMMotionManager 래퍼 (MotionTracker)
  ├── Storage/      # 인메모리 버퍼 + 바이너리 파일 플러시                                                    
  └── Transfer/     # WCSession 파일 전송 서비스

  JeonstarLab Mac/       (macOS)
  ├── App/
  ├── Connectivity/      # Mac 수신기(MultipeerConnectivity advertiser)
  ├── Export/            # 폴더 기반 데이터셋 CSV 내보내기
  ├── Models/            # 수신 패키지, 스냅, 폴더, 사용자 정보 모델
  ├── Services/          # CSV/JSON 파서, 세그먼트 생성, 폴더 저장소
  ├── ViewModels/
  └── Views/             # 녹화 상세, 그래프, 스냅 목록, 폴더 상세
```

# Mac 라벨링 데이터

Mac 앱은 원본 `recording.csv`, `metadata.json`, `snap_analysis.json`을 직접 수정하지 않습니다.
사용자가 편집한 정보는 수신 패키지 폴더의 사이드카 파일에 저장합니다.

| 파일 | 역할 |
|---|---|
| `label.json` | 표시 이름, 고정 여부, 녹화별 사용자 정보, 스냅 라벨/노트, 수동·수정·삭제 스냅 정보 |
| `folders.json` | Mac 전체 폴더 분류와 폴더에 포함된 스냅 참조 |
| `segments/<snapID>/segment.csv` | 개별 스냅 구간의 샘플 데이터 |
| `segments/<snapID>/segment_metadata.json` | 스냅 구간의 메타데이터와 라벨 정보 |

폴더 기반 데이터셋 내보내기는 여러 스냅 세그먼트를 하나의 CSV로 합치며, 각 행은 `snapID`, `sampleIndex`, 모션 값, `label`을 포함합니다.


# 깃 전략

### 태그 컨벤션

`init` : 가장 처음 Initial Commit에 태그 붙이기

`feat` : 새로운 기능 구현 시 사용

`fix` : 버그나 오류 해결 시 사용

`docs` : README, 템플릿 등 프로젝트 내 문서 수정 시 사용

`setting` : 프로젝트 관련 설정 변경 시 사용

`add` : 사진 등 에셋이나 라이브러리 추가 시 사용

`refactor` : 기존 코드를 리팩토링하거나 수정할 시 사용

`chore` : 별로 중요한 수정이 아닐 시 사용

### 커밋 컨벤션

태그는 반드시 **소문자**로 작성합니다.

내용은 한글로 작성합니다.

제목이 **50자**를 넘지 않도록, 간단하게 명령조로 작성합니다. 설명이 필요한 경우 description에 작성!

```markdown
[feat] 로그인 기능 구현
```

### 브랜치 컨벤션

태그/#이슈번호-작업하는 파일

```markdown
feat/#1-loginUI
```

### 브랜치 전략

`main` : 출시(release)에 사용하는 브랜치입니다.

`develop` : 개발된 기능들을 최종적으로 합쳐서 확인하는 브랜치입니다.
- 기본 브랜치이며 개발을 마친 후에 반드시 develop에 머지합니다.
- 개인 브랜치에서 작업을 마치면, 개인 브랜치에서 develop 브랜치를 머지한 후헤 develop에 pull request를 요청합니다.

`feature` : 태그를 붙이는 모든 브랜치들을 말합니다. 기능 개발, 버그 수정 등을 반드시 이 브랜치에서 진행해주세요.


# 적용된 디자인 패턴
                    
### Clean Architecture (레이어드 아키텍처)
                                                                                                              
  Models → Protocols → UseCases → ViewModels → Views 순으로 의존 방향을 단방향으로 유지합니다. 상위 레이어는  
  하위 레이어를 모르고, 하위 레이어는 프로토콜만 바라봅니다.                                                  
                                                                                                              
### MVVM            

  @Observable ViewModel이 View의 상태를 소유하고, View는 ViewModel을 읽기만 합니다. Watch 앱의                
  RecordingViewModel, iPhone 앱의 WatchControlViewModel·RecordingListViewModel이 이 역할을 담당합니다.

### Repository Pattern

  RecordingRepository가 SwiftData(메타데이터)와 FileManager(바이너리 파일) 두 저장소를 하나의 인터페이스로    
  추상화합니다. 뷰모델은 저장 구현을 알 필요가 없습니다.
                                                                                                              
### Use Case Pattern

  비즈니스 로직 하나를 클래스 하나에 담습니다.                
  - StartRecordingUseCase – 새 UUID로 녹음 시작
  - StopRecordingUseCase – 버퍼 플러시 → 메타데이터 생성 → 파일 전송                                          
  - ImportRecordingUseCase – 수신 파일 파싱 → 타임스탬프 기반 트리밍 → 저장

### Protocol-Driven Design

  MotionRecorderProtocol, RecordingStorageProtocol, RecordingTransferProtocol 등 핵심 서비스는 모두 프로토콜로 정의합니다. 구현체는 플랫폼별로 분리되어 있어 테스트·교체가 용이합니다.

### Dependency Injection (생성자 주입)

  앱 진입점(Wrist_MotionApp)에서 모든 의존성을 생성하고 생성자로 주입합니다. 이벤트 콜백은                    
  클로저(onFileReceived, onCommandReceived)로 연결하여 결합도를 낮춥니다.

### State Machine

  RecordingState (idle / recording / transferring), WatchState (notConnected / idle / recording) 등 enum으로  
  상태를 모델링합니다. 유효하지 않은 전이를 컴파일 타임에 차단합니다.
                                                   
### Custom Binary Serialization (WMTF 포맷)

  고정 크기(104 bytes) MotionSample 구조체를 unsafe memory binding으로 직접 직렬화합니다. JSON 파싱 오버헤드  
  없이 대용량 센서 데이터를 효율적으로 저장·전송합니다. 파일 앞에 매직 바이트(WMTF)와 버전 헤더를 붙여 포맷
  식별 및 하위 호환을 지원합니다.
