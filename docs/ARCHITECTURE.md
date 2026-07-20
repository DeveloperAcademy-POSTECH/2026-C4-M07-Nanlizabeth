# 🏗️ 기타싱크 설계 문서 (ARCHITECTURE) — "어떻게" 만드나

> **문서 3형제:** [SPEC.md](SPEC.md)(무엇을) · [ARCHITECTURE.md](ARCHITECTURE.md)(어떻게) · [ROADMAP.md](ROADMAP.md)(무슨 순서로)
> 여기엔 ①현재 어디까지 됐나 ②목표 폴더 구조 ③**공통 인터페이스(계약) 카탈로그** ④병렬 개발 방법이 있습니다.

**초보자를 위한 읽는 법:** 전부 읽을 필요 없어요. ROADMAP에서 자기 태스크를 확인하면 그 태스크에 "관련 계약: §3.x"가 적혀 있습니다. **그 절만 읽으면 됩니다.** 계약 = "이런 이름의 기능이 이렇게 들어오고 나온다"는 껍데기 약속. 껍데기만 지키면 남의 코드를 몰라도 내 것과 맞물립니다.

---

## 1. 현재 구현 현황 (2026-07-20 기준)

> ✅ **Phase 0(기반)과 Phase 1(계약+Mock)이 끝났습니다.** 이제 6개 레인이 동시에 출발할 수 있습니다.
> 계약은 전부 `프로토콜 + 기본 구현 + Mock + 사용 예시 주석` 형태로 들어가 있으니,
> 자기 태스크의 관련 계약 파일을 열어 주석부터 읽으면 됩니다.
>
> | Phase | 태스크 | 상태 |
> |-------|--------|------|
> | 0 | F1 레이아웃 규약 · F2 토큰 · F3 라우터 · F4 폴더 · F5 온보딩 정책 | ✅ (F2는 Figma 값 대기) |
> | 1 | C1 클럭 · C2 카탈로그 · C3 운지 · C4 주법 · C5 진행 · C6 세션 · C7 연결 | ✅ |


### ✅ 이미 있는 것

| 영역 | 파일 | 상태 |
|------|------|------|
| 소리 엔진 계약 | `Domain/Audio/GuitarAudioEngineProtocol.swift` | ✅ 두 엔진의 공통 껍데기 |
| 소리 엔진 공통 로직 | `Domain/Audio/GuitarAudioEngineBase.swift` | ✅ 음 계산·벨로시티·자동 정지 |
| Native 엔진 | `Domain/Audio/NativeAudioEngine.swift` | ✅ AVAudioEngine + 샘플러 6개 + 리버브 |
| AudioKit 엔진 | `Domain/Audio/AudioKitAudioEngine.swift` | ✅ 패키지 없어도 컴파일되게 가드됨 |
| 엔진 팩토리 + A/B 토글 | `Domain/Audio/GuitarAudioEngineFactory.swift`, `Features/Shared/DebugAudioEngineToggle.swift` | ✅ 재빌드 없이 런타임 교체 |
| 스트럼 입력 계산 | `Features/Strum/GuitarStrumViewModel.swift` | ✅ 좌표→줄 매핑, 긁는 속도→세기(velocity) |
| 통신 | `Services/Multipeer/` (서비스·코덱·메시지) | ✅ 운지(`.fingering`) 전송까지 실동작 |
| 코드 데이터 | `Domain/Fingering/GuitarChord.swift`(7개) + `Domain/Fingering/GuitarFingering.swift` | 🟡 카탈로그로 확장 필요 |
| 화면 4종 | `Features/` | 🟡 와이어프레임(더미 데이터) |
| Mock 예시 | `Services/Sound/MockSoundPreviewService.swift` | ✅ **우리 프로젝트의 Mock 패턴 표본** |
| 통신 권한 문구 | `Config/Info.plist` (로컬네트워크·Bonjour·블루투스) | ✅ 이미 등록됨 |

### 🆕 이번에 추가된 것 (Phase 0·1)

| 영역 | 파일 | 태스크 |
|------|------|--------|
| 박자 클럭 | `Domain/Clock/BeatClock.swift` (+`MockBeatClock`) | C1 |
| 코드 카탈로그 | `Domain/Fingering/ChordCatalog.swift` + `Content/ChordCatalogData.swift` | C2 |
| 운지 상태 | `Domain/Fingering/FingeringState.swift` (+Mock) | C3 |
| 주법 | `Domain/Strum/StrumPattern.swift`·`StrumPatternLibrary.swift` + `Content/StrumPresetData.swift` | C4 |
| 코드진행 | `Domain/Progression/ChordProgression.swift`·`ChordProgressionLibrary.swift` + `Content/ProgressionPresetData.swift` | C5 |
| 세션(모드 조립) | `Domain/Session/PlaySession.swift`·`PlaySources.swift` | C6 |
| 연결 정책 | `Services/Multipeer/PeerRolePolicy.swift` | C7 |
| 라우터·온보딩 저장 | `App/AppRouter.swift`·`AppRootView.swift` | F3 |
| 디자인 토큰 | `DesignSystem/Tokens/` (Layout·Color·Typography·Spacing) | F1·F2 |

### ⛔ 아직 없는 것 (남은 Phase 2·3)

- **스트럼 화면 시각화 + iPad 레이아웃** (이미지→벡터 재작성, SPEC §8 iPad 결정 대기)
- **모드 B/C 화면 연결** (위 스트럼 화면과 함께 — 모드 A는 연결됨)
- `gs_instruments.dls`(에셋) · 성능·지연 계측(A2, 기기) · **H2 Core Haptics 감쇠**(기기)
- 콘텐츠 리서치(CT1~3) · 통합 QA·엔진 결정(I4·I5, 기기)

> ✅ **Phase 2에서 `develop`에 병합된 것 (PR #4~#15):**
> A4 오디오 세션 복구 · **L2·L3·L4** 플레이어(주법·진행·미리듣기, 실구현) ·
> **I1·I2·I3** 세 모드 조립(`ChordPracticeSession`·`StrumPracticeSession`·`EnsembleStrummerSession`) ·
> **N1** 원격 소스 배선 · **H1** 발음 햅틱 · **H3** 판정 햅틱(메커니즘) ·
> 화면 **U1·U2·U4·U5·U6·U7** + U3 멀티터치 입력 ·
> **모드 A 화면 연결**(`ChordModeController` — 넥에서 짚고 재생하면 자동 스트럼).
>
> 세 모드 전부 **기록형 가짜 엔진 + `MockBeatClock`으로 로직 체인 검증**됨. 남은 검증은 실기기 소리·햅틱.
>
> 🖐️ **멀티터치는 `DesignSystem/Components/MultiTouchLayer.swift` 하나를 넥·스트럼이 공유합니다.**
> SwiftUI `DragGesture`는 손가락을 **하나만** 주기 때문에 기타 앱에서는 쓸 수 없습니다 — 화음을 짚거나
> 여러 줄을 동시에 튕기려면 이 레이어를 쓰세요. 좌표를 의미로 바꾸는 일(어느 줄·어느 프렛)은
> 레이어가 아니라 **화면 쪽**에서 합니다.
>
> ⚠️ **U2가 남긴 정리 항목:** 프로토타입 셸(`Features/Shared/MainInstrumentScreen`)에서 **오디오 엔진이 두 벌** 만들어집니다 — 넥·스트럼 뷰모델이 각자 만들기 때문입니다. 소리가 겹치지는 않지만 메모리를 두 배로 쓰므로 **A3의 메모리 실측이 왜곡됩니다.** 엔진 소유를 세션 코디네이터(§3.7)로 옮기는 **태스크 L5에서 해소**됩니다.

---

## 2. 폴더 구조 ✅ 적용 완료 (2026-07-20, 태스크 F4)

**폴더를 고르는 규칙 다섯 줄 (이것만 기억):**
1. 화면 없이 돌아가는 규칙(로직) → `Domain/`
2. 눈에 보이는 화면 → `Features/` (화면마다 폴더 하나: View + ViewModel 셋트)
3. 기기·시스템 연동(통신·햅틱·로그) → `Services/`
4. 프리셋 데이터(운지표·리듬·코드진행 — 코드가 아니라 **데이터**) → `Content/`
5. 색·여백·공용 부품 → `DesignSystem/`

```
GuitarSync/
├── App/                          # 진입점 + 화면 길안내
│   ├── GuitarSyncApp.swift
│   ├── RootView.swift
│   └── AppRouter.swift              [새로] §3.9
│
├── DesignSystem/
│   ├── Tokens/                      [새로] Colors·Spacing·Typography·Radius (Figma 값)
│   └── Components/                  (기존 LiquidGlass 버튼 등 + 새 공용 부품)
│
├── Domain/                          [새 폴더] ★화면 없이 돌아가는 비즈니스 로직
│   ├── Audio/                       (Services/Audio 전체 이동 — 내용 그대로)
│   ├── Clock/                       BeatClock (박자 심장) §3.2
│   ├── Fingering/                   FingeringState·ChordCatalog·FretPress §3.3~3.4
│   ├── Strum/                       StrumPattern·Library·Player §3.5
│   ├── Progression/                 ChordProgression·Library·Player·Preview §3.6
│   └── Session/                     소스 2종 + PlaySessionCoordinator + PlayMode §3.7
│
├── Content/                         [새 폴더] 프리셋 데이터 (리서치 결과가 들어오는 곳)
│   ├── ChordCatalogData.swift          코드 운지표 (C, Am, F, G7 …)
│   ├── StrumPresetData.swift           주법 프리셋 (칼립소, 고고 …)
│   └── ProgressionPresetData.swift     진행 프리셋 (머니코드, 캐논 …)
│
├── Features/                        화면 단위 (기존 Views/·ViewModels/ 재편 — Views/·ViewModels/ 폴더는 사라짐)
│   ├── Onboarding/                  [새로]
│   ├── Neck/                        ScreenshotFretboardView
│   ├── Strum/                       GuitarStrumView + ViewModel + 줄 입력/이미지 뷰
│   ├── StrokeSelect/                StrumSelectScreen
│   ├── ProgressionSelect/           ChordProgressionScreen
│   ├── ProgressionCustom/           [새로]
│   ├── PeerConnect/                 [새로] 가이드 + 근처 기기 찾기
│   └── Shared/                      ⚠️프로토타입 셸 — 라우터(F3)가 대체하면 정리 대상
│                                    (ScreenshotPrototypeView/ViewModel, MainInstrumentScreen,
│                                     TopControlBar, BPMPopover, DebugAudioEngineToggle)
│
├── Services/                        시스템 연동 (Audio는 Domain으로 이사)
│   ├── Multipeer/  Haptics/  Device/  Logging/  Sound/
│
├── Models/                          공용 순수 모델 (StrumDirection, 좌표 규약 등)
└── Resources/                       gs_instruments.dls (예정), 이미지 등
```

> 📦 **기존 파일 이사는 초기에 딱 1회, 한 사람이** 합니다 (ROADMAP 태스크 F4). ✅ **완료됨.** 이후에는 위 규칙대로만 새 파일을 만드세요.
>
> 🧭 **어디에 둘지 헷갈릴 때 실제로 쓴 판단 기준:** 두 화면 이상이 쓰거나 화면과 무관하면 `DesignSystem/Components/`, 한 화면 전용이면 그 화면 폴더. (예: `HeaderBar`는 3개 화면이 써서 DesignSystem, `BPMPopover`는 한 화면만 써서 그 화면 옆)

---

## 2.5 레이아웃 규약 ✅ 확정 (2026-07-20, 태스크 F1)

**한 줄:** 앱은 세로 고정이고, 스테이지가 콘텐츠를 회전시켜 가로를 만든다. 화면은 전부 **852×393 도화지 하나**에만 그린다.

| 항목 | 결정 |
|------|------|
| 지원 기기 | iPhone · iPad (`TARGETED_DEVICE_FAMILY = 1,2`) |
| 방향 | **iPhone = 세로 고정 + 스테이지가 -90° 회전**으로 가로 생성 · **iPad = 가로 네이티브(회전 없음)** (`Info.plist` `~ipad` = Landscape, 2026-07-21) |
| 기준 해상도 | **874×402** (Figma HI-FI iPhone 프레임 = iPhone 16 Pro/17 가로) = `LayoutTokens.phoneStage` |
| 반응형 정책 | **기준 해상도 + 비율 스케일(fit).** 기기별 재배치 없음 — 스테이지가 통째로 축소/확대 |
| 화면 담당이 할 일 | 없음. **874×402에 좌표를 잡으면 끝.** 기기 분기 금지 |

> ✅ **iPad 90° 회전 문제 해결 (2026-07-21).** iPad는 세로 고정을 풀고 **가로 네이티브**로 뜨며,
> `PortraitLockedLandscapeStage`가 iPad에선 **회전하지 않는다**(`deviceType == .iPad` 분기).
> iPhone은 그대로 세로 고정 + 회전.
>
> ⚠️ **다만 iPad 전용 레이아웃은 아직입니다 (SPEC §8 결정 대기).** 지금은 iPhone 도화지(874×402)를
> 그대로 키워 보여주므로 **위아래에 여백**이 생깁니다. Figma HI-FI엔 **iPad Pro 12.9" 전용 프레임
> (1366×1024)** 이 따로 있고(사운드홀 크게, 줄이 화면을 관통) 단순 확대가 아니라 4:3 재배치라,
> `LayoutTokens.padStage`를 기준으로 새로 짜야 합니다. **iPad는 모드 C의 소리 나는 쪽**이라 무시 못 함.

**왜 회전 방식을 유지하나:** 기기를 돌려도 화면이 뒤집히지 않고, 회전 애니메이션도 없다. 악기를 든 자세가 고정된 앱에 맞는 동작이다. 이미 동작하는 코드라 교체 비용도 없다.

### ⚠️ 이 방식의 알려진 비용 — 다음 3가지는 반드시 예외 처리할 것

회전은 **우리 콘텐츠에만** 걸린다. iOS가 직접 띄우는 UI는 **실제 세로 방향으로 뜨므로 90° 어긋나 보인다.**

| 부딪히는 곳 | 증상 | 담당 태스크의 대응 |
|------------|------|------------------|
| **로컬 네트워크 권한 팝업** (SPEC 플로우 3) | 시스템 알림이 세로로 뜸 | U7 연결 가이드에서 **"팝업이 옆으로 보일 수 있어요"까지 예고**. 팝업 뜨는 순간 안내 문구를 세로로 함께 배치 |
| **`MPVolumeView` 볼륨 슬라이더** (SPEC 플로우 4) | UIKit 뷰라 회전 상속이 어긋남 | U1 온보딩에서 **볼륨 카드만 회전 없이** 배치하거나, 슬라이더 대신 "설정에서 올려주세요" 안내로 대체 |
| **VoiceOver 등 접근성** (태스크 H4) | 읽기 순서·스와이프 방향이 화면 좌표 기준이라 어긋남 | H4에서 `accessibilityRotor`·명시적 `accessibilitySortPriority`로 순서를 **직접 지정**. 자동 순서에 기대지 말 것 |

> 📌 위 3건은 "나중에 놀라지 않기 위해" 적어둔 것입니다. 규약 자체는 확정이고, 각 태스크에서 위 대응만 챙기면 됩니다.

### 코드에서 쓰는 법

- 기준 크기·배율: `DesignSystem/Tokens/LayoutTokens.swift`
- 화면을 감싸는 곳: `PortraitLockedLandscapeStage { ... }`
- **실제 물리 거리가 필요한 계산**(제스처 임계값, 스트럼 속도→세기)에만 `@Environment(\.stageScale)`을 곱해 쓴다. 그 외엔 신경 쓸 필요 없다.
- 기존 `GuitarLayoutConstants`의 고정 수치(넥 760×310 등)는 **이 기준 해상도를 전제로 한 값**이라 그대로 유효하다.

---

## 3. 공통 계약 카탈로그 ★이 문서의 심장

각 계약마다: **책임 한 줄 → 주요 기능 명세 → 만드는 사람/쓰는 사람 → 쉬운 설명** 순서입니다.
(메서드 이름은 확정 제안입니다. 계약 담당자가 구현하며 다듬되, **바꾸면 반드시 팀 공지 + 이 문서 수정**.)

### 3.1 `GuitarAudioEngineProtocol` (✅ 있음) — Domain/Audio

**책임:** "소리 내라/멈춰라" 명령의 공통 껍데기. Native와 AudioKit 둘 다 이걸 구현.

| 기능 | 명세 |
|------|------|
| `start()` / `stop()` | 엔진 켜기/끄기 |
| `pluckString(stringIndex:fretNumber:velocity:)` | 한 줄 튕기기 (몇 번 줄, 몇 프렛, 세기 0~127) |
| `pluckStringSequence(_:frets:baseVelocity:interval:)` | 여러 줄을 시차 두고 차례로 |
| `strum(frets:direction:velocity:interval:)` | 6줄 전체를 방향대로 긁기 |
| `stopString(stringIndex:)` / `stopAllStrings()` | 줄 소리 멈춤 |

- **만드는 사람:** 소리 담당(이미 완성) · **쓰는 사람:** 소리가 나는 모든 로직(플레이어·운지 상태)
- ⏳ **어느 엔진을 쓸지는 출시 직전까지 결정하지 않습니다** — 그동안 둘 다 계약 뒤에 살려두고 성능 데이터만 쌓습니다 ([ROADMAP §2](ROADMAP.md)).
- 🗣️ *쉬운 설명: 앰프에 꽂는 잭. 잭 규격(계약)만 같으면 앰프(엔진)가 뭐든 소리가 난다.*

> ⚠️ **악기 앱이라 반드시 챙겨야 하는데 초안에 빠졌던 책임 (검토로 추가):**
> - **지연(latency)** — 터치→소리가 체감상 즉각이어야 한다. **악기 앱의 1순위 지표**(메모리·발열보다 위). `setPreferredIOBufferDuration`은 5ms로 잡혀 있으나 **실제 체감 지연을 측정**해야 한다 → ROADMAP A2. 엔진 최종 선택 기준에도 **지연을 포함**한다.
> - ~~**중단·경로 변경 대응**~~ → ✅ **A4에서 완료.** 아래 §3.1.1 참고.
> - **폴리포니 상한** — 6현 + 잔향이 겹치면 보이스가 폭증한다. 동시 발음 상한·오래된 보이스 회수 정책을 둔다.

#### 3.1.1 `AudioSessionController` (✅ 있음, 태스크 A4) — Domain/Audio

**책임:** 소리가 죽는 상황을 감시해 엔진을 되살린다. **`GuitarAudioEngineProtocol`은 바뀌지 않았다** — 쓰는 쪽 코드는 그대로다.

| 감시 사건 | 언제 | 대응 |
|-----------|------|------|
| 중단(interruption) | 전화·알람·Siri | 시작 시 엔진 정지 → 끝나면 세션 재활성 + 재구동 |
| 경로 변경(route change) | 이어폰 꽂고 뺌·블루투스 전환 | 기기가 빠지면 **울리던 소리만** 끊고(엔진은 유지), 새 경로가 잡히면 재구동 |
| 미디어 서비스 리셋 | 오디오 데몬이 죽었다 살아남 (드묾) | 그래프 전면 재구축 |
| 앱 활성화/비활성화 | 백그라운드 복귀·홈으로 나감 | 복귀 시 재구동 / 나갈 때 소리 끊기 |

- **복구 계약:** `AudioSessionRecoverable` (`cutSoundingNotes` / `suspendForInterruption` / `resumeAfterInterruption` / `rebuildAudioGraph`). `GuitarAudioEngineBase`가 구현하므로 **두 엔진이 그대로 물려받는다.**
- **엔진별 몫:** `isEngineRunning`과 `rebuildEngine()` 오버라이드 2개뿐. 세 번째 엔진이 생겨도 이 둘만 채우면 된다.
- ⚠️ **세션 설정은 `AudioSessionController.configureSession()` 한 곳에서만** 한다. 카테고리·버퍼 길이를 여러 곳에서 바꾸면 누가 마지막에 덮었는지 추적이 안 된다.
- ⚠️ **재개 성공 여부를 반드시 확인한다** — 경로 변경 뒤에는 하드웨어 포맷이 달라져 `start()`가 조용히 실패한다. 실패하면 그래프를 새로 만든다.
- 🗣️ *쉬운 설명: 정전이 나도 알아서 다시 켜지는 앰프. 전화 받고 나면 소리가 안 나던 문제가 이것.*
- 📌 **시뮬레이터로는 검증이 안 된다** — 실기기 확인 항목은 [ROADMAP A4](ROADMAP.md) 참고.

### 3.2 `BeatClockProtocol` [새로] — Domain/Clock

**책임:** BPM에 맞춰 "지금 몇 마디, 몇 박, 몇 번째 16분음표"를 계속 방송하는 박자 심장. **자동 스트럼·자동 코드진행·미리듣기·(카운트인)이 전부 이 하나에 맞춰 움직인다.**

| 기능 | 명세 |
|------|------|
| `start(bpm:timeSignature:)` | 시작. `TimeSignature`는 `(beatsPerBar: 4, noteValue: 4)` 같은 박자표 |
| `stop()` | 정지 |
| 박 이벤트 구독 | `BeatEvent { barIndex, beatIndex, subIndex }` 를 16분음표 단위로 방송 (Combine Publisher 또는 콜백) |
| `isRunning` / `currentBPM` | 상태 노출 (`@Published`) |

- **만드는 사람:** 로직 담당 1명 · **쓰는 사람:** StrumPatternPlayer, ProgressionPlayer, PreviewPlayer
- ⚠️ 구현 주의: `Timer`는 밀립니다(드리프트). 최소 `DispatchSourceTimer` + 시작 시각 기준 절대 계산으로 만들 것. **음악적으로 더 촘촘한 정확도가 필요하면** 오디오 엔진 자체 클럭(샘플 단위 스케줄링, `AVAudioTime`/시퀀서)이 정석 — UI 타이머가 충분히 안 촘촘하면 이쪽으로 갈지 **결정 필요**(기술 리스크).
- 🗣️ *쉬운 설명: 메트로놈 라디오 방송국. 누구든 주파수만 맞추면(구독) 같은 박자를 듣는다.*

### 3.3 `ChordCatalog` (확장) — Domain/Fingering

**책임:** "코드 이름 → 운지(어느 줄 몇 프렛)"의 **전사 공용 사전.** 프리셋 진행·커스텀 진행·기타넥 표시가 **전부 이 하나만** 본다. (→ "커스텀에서 프리셋 코드를 재사용"이 저절로 됨)

| 기능 | 명세 |
|------|------|
| `GuitarChord` 확장 | 기존 7개 → C7·Cm·CM7·Dm7·F·B7 등 추가 (목록은 콘텐츠 태스크 CT3에서 확정) |
| `fingering(for: GuitarChord) -> GuitarFingering` | 운지 조회 (기존 `chord.fingering` 확장) |
| `allChords` / `chords(root:)` | 전체 목록·근음별 필터 (선택 화면용) |

- **만드는 사람:** 계약은 로직 담당, **데이터 채우기는 리서치 담당**(코드 몰라도 운지표만 채우면 됨 → `Content/ChordCatalogData.swift`)
- **규약(전 팀 공통, SPEC §4와 동일):** `stringIndex 0 = 6번줄(저음E)`, `frets: -1=뮤트 / 0=개방 / 1~=프렛`
- 🗣️ *쉬운 설명: 기타 코드 사전책. 모두가 같은 책을 봐야 "C코드"가 사람마다 다르지 않다.*

### 3.4 `FretboardInput` ↔ `FingeringState` [새로] — Domain/Fingering ★개별 발음 베스트 프랙티스

**책임:** 기타넥 터치를 받아 ①현재 운지 상태를 관리하고 ②정책에 따라 그 줄을 즉시 발음시키고 ③UI가 그릴 이벤트를 되돌려준다. **SPEC §4(핑거보드 개별 발음)의 해답.**

**데이터 흐름 (이 그림이 곧 인터페이스):**

```
[UI: 넥 화면]                          [Domain: FingeringState]                [Audio]
터치 감지                                                                     
  → FretPress(stringIndex, fret)로 변환  
  → pressesChanged(Set<FretPress>) 호출 → 운지 상태 갱신                        
                                        → 정책이 pluckOnPress면              
                                          새로 눌린 줄마다 ──────────────────→ pluckString(...)
                                        → notePlayed(stringIndex, velocity)   
  줄 반짝/진동 애니메이션 ←──────────────  이벤트 방송                          
  currentFingering 구독해서              @Published currentFingering           
  짚힌 자리 표시 ←─────────────────────  (멀티피어 전송에도 이걸 사용)          
```

| 기능 | 명세 |
|------|------|
| `FretPress` | `{ stringIndex: Int, fret: Int }` — 터치 1개의 의미 |
| `pressesChanged(_ presses: Set<FretPress>)` | **UI가 호출.** 지금 눌려 있는 모든 칸을 통째로 전달 (멀티터치를 스냅샷으로 — began/ended 낱개보다 동시 터치 꼬임이 없음) |
| `currentFingering: GuitarFingering` | `@Published` — 지금 짚힌 운지. UI 표시·멀티피어 전송·자동 스트럼이 공용 |
| `notePlayed` 이벤트 | `{ stringIndex, velocity }` 방송 — UI 애니메이션·햅틱이 구독 |
| `soundPolicy: FretSoundPolicy` | `.pluckOnPress`(누르는 순간 발음 — 모드 A·C의 넥) / `.silent`(짚기만 — 필요시) |

- **만드는 사람:** 로직 담당 · **쓰는 사람:** 넥 화면 UI(호출+구독), 세션 코디네이터, 멀티피어
- **병렬 포인트 (이게 베스트 프랙티스):**
  - **UI 담당은** "터치 좌표 → `FretPress` 변환"과 "`notePlayed` 구독 → 그리기"만 하면 됨. 소리·상태 로직 몰라도 됨. 좌표 변환은 기존 `stringIndex(from:in:configuration:)` 패턴 재사용.
  - **로직 담당은** 터치가 어떻게 들어오는지 몰라도 됨. `Set<FretPress>`만 받으면 끝.
  - 서로 기다릴 필요 없음: UI는 **Mock FingeringState**(아무 입력에나 고정 응답)로 먼저 개발.
- 🗣️ *쉬운 설명: UI는 "여기 눌렸어요"라고 쪽지(FretPress)만 넘기고, 로직은 쪽지만 보고 소리·상태를 처리한 뒤 "3번 줄 울렸어요"라고 방송한다. 서로의 속사정을 모른다.*

### 3.5 스트럼 패턴 계약 [새로] — Domain/Strum

**책임:** "주법(리듬) 하나"를 데이터로 표현하고, 저장하고, 박자에 맞춰 자동 연주한다.

**모델 (이 모양만 지키면 어떤 리듬이든 꽂힌다):**

| 타입 | 명세 |
|------|------|
| `StrumPattern` | `{ id, name, timeSignature, steps: [StrumStep], source: .preset/.custom }` — `Codable` |
| `StrumStep` | `{ position: BeatPosition, direction: .up/.down, accent: .strong/.medium/.soft, isMute: Bool }` |
| `BeatPosition` | `{ bar, beat, sub }` — 마디 안 어디서 긁는지, 16분음표 단위 |

**리서치 담당을 위한 예시** — 칼립소(♩=한 박): "1박 다운, 2박 반 다운·업, 3박 쉼, 3박 반 업, 4박 다운·업" → `StrumStep` 6개로 표 채우듯 입력. **코드 지식 불필요, 표만 채우면 됨** (`Content/StrumPresetData.swift`).

| 프로토콜 | 명세 |
|------|------|
| `StrumPatternLibraryProtocol` | `presets: [StrumPattern]`, `pattern(id:)` — **읽기 전용.** 주법 커스텀은 범위에서 제외됨(2026-07-20) |
| `StrumPatternPlayerProtocol` | `play(pattern:looping:)`, `stop()` — 클럭(§3.2) 구독, 각 step 시점에 현재 운지로 오디오 호출. `strumPerformed` 이벤트 방송(UI 표시용) |

- **만드는 사람:** 계약+플레이어는 로직 담당, 프리셋 데이터는 리서치 담당 · **쓰는 사람:** 스트로크 선택 화면, 모드 A, 미리듣기
- 🗣️ *쉬운 설명: 주법을 악보(데이터)로 적어두면, 플레이어(자동 오른손)가 메트로놈에 맞춰 그대로 긁어준다.*

### 3.6 코드진행 계약 [새로] — Domain/Progression

**책임:** "코드 순서 + 각 코드 길이"를 데이터로 표현·저장하고, 시간에 따라 자동으로 짚어주고, 미리듣기를 재생한다.

| 타입 | 명세 |
|------|------|
| `ChordProgression` | `{ id, name, items: [ProgressionItem], source: .preset/.custom }` — `Codable` |
| `ProgressionItem` | `{ chord: GuitarChord, barCount: Int }` — "이 코드를 몇 마디" |

| 프로토콜 | 명세 |
|------|------|
| `ChordProgressionLibraryProtocol` | `presets`(머니코드 C→G→Am→F, 캐논 등 — `Content/`에서), `customs`, `saveCustom(_:)`, `deleteCustom(id:)` |
| `ChordProgressionPlayerProtocol` | `start(progression:bpm:looping:)`, `stop()` — 클럭 구독, 마디가 넘어가면 `currentChord`/`currentFingering`(`@Published`) 갱신 + `chordChanged` 이벤트. **이게 모드 B의 "자동 왼손"** |
| `ProgressionPreviewPlayerProtocol` | `preview(_ progression:)`, `previewChord(_ chord:)`, `stopPreview()` — 기본 주법·기본 BPM으로 짧게 재생. **항상 하나만**: 새 미리듣기가 이전 것을 자동 정지 |

- **만드는 사람:** 계약+플레이어 로직 담당, 프리셋 데이터 리서치 담당 · **쓰는 사람:** 진행 선택/커스텀 화면, 모드 B
- 커스텀 화면이 코드를 고를 때는 **반드시 §3.3 카탈로그에서** — 별도 코드 목록 금지.
- 🗣️ *쉬운 설명: 노래방 반주기의 왼손 버전. 정해둔 순서대로 때가 되면 코드를 갈아 짚어준다.*

### 3.7 소스와 코디네이터 [새로] — Domain/Session ★이 앱의 심장

**책임:** SPEC §2의 "왼손 × 오른손 = 3가지 방식" 표를 코드 구조로 옮긴 것. **모드 = 플러그 조합.**

| 프로토콜 | 명세 | 구현 3종 |
|------|------|---------|
| `FingeringSourceProtocol` | `currentFingering: GuitarFingering` (`@Published`) — "지금 왼손이 뭘 짚고 있나" 제공 | `ManualFingeringSource`(넥 터치, §3.4를 감쌈) / `AutoFingeringSource`(진행 플레이어 §3.6) / `RemoteFingeringSource`(피어 수신 §3.8) |
| `StrumSourceProtocol` | 스트럼 이벤트 방송: `strumOccurred(direction, velocity)` / `pluckOccurred(stringIndex, velocity)` — "오른손이 언제 어떻게 긁었나" | `ManualStrumSource`(줄 화면 터치) / `AutoStrumSource`(패턴 플레이어 §3.5) / `RemoteStrumSource`(피어 수신) |
| `PlaySessionCoordinator` | `init(fingeringSource:strumSource:audioEngine:)` — 스트럼 이벤트가 오면 **그 순간의 운지**로 오디오 호출. `setMode(PlayMode)`로 소스 갈아끼움 | (클래스 하나) |

**`PlayMode` 조합표 (SPEC §2와 1:1):**

| 모드 | fingeringSource | strumSource |
|------|----------------|-------------|
| A 코드 연습 | Manual | Auto |
| B 스트로크 연습 | Auto | Manual |
| C 합주 · iPad 쪽 | **Remote** | Manual |
| C 합주 · iPhone 쪽 | Manual (전송만, 소리 없음) | — |

- **만드는 사람:** 로직 담당 · **쓰는 사람:** 메인 화면들(모드 전환 버튼), 앱 전체
- 🗣️ *쉬운 설명: 멀티탭. 왼손 플러그와 오른손 플러그를 어느 콘센트에 꽂느냐만 바꾸면 모드가 바뀐다. 본체(코디네이터)는 그대로.*

### 3.8 Multipeer (✅ 있음 + 보강) — Services/Multipeer

**있음:** `MultipeerServiceProtocol`(광고/탐색/초대/전송/콜백), `PeerMessage`(`.fingering` 등), 코덱. Info.plist 권한 문구도 등록 완료.

**보강할 것:**

| 항목 | 명세 |
|------|------|
| `PeerRolePolicy` | **iPad → 항상 스트로크(오른손), iPhone → 항상 코드(왼손).** 협상 없음. 기존 `DeviceType`으로 판정 |
| `ConnectionFlowState` | `idle → guide(첫 회만) → browsing → inviting → connected → disconnected` — 연결 UI(화면 8·9)가 이 상태만 보고 그림 |
| `hasSeenPeerGuide` | `UserDefaults` — 봤거나 스킵했으면 다음부터 guide 단계 건너뜀 |
| `RemoteFingeringSource` / `RemoteStrumSource` | 수신 메시지를 §3.7 소스 계약으로 감쌈 — 코디네이터는 원격인지도 모름 |

- 🗣️ *쉬운 설명: 무전기는 이미 있다. "누가 어느 역할인지 고정"과 "처음 쓰는 사람용 안내 순서"만 정하면 된다.*

### 3.9 `AppRouter` [새로] — App/

**책임:** "무슨 버튼 → 무슨 화면"을 **한 곳에서** 관리. 화면 전환 방식이 사람마다 달라지는 것을 막는다.

| 기능 | 명세 |
|------|------|
| `AppRoute` (enum) | SPEC §6 화면 목록과 1:1 — `.onboarding, .neck, .strum, .strokeSelect, .strokeCreate, .progressionSelect, .progressionCustom, .peerGuide, .peerBrowse` |
| `navigate(to:)` / `back()` | 이동. `@Published currentRoute`(또는 path) |
| 시작 규칙 | 첫 실행 → `.onboarding` · iPhone → `.neck` · iPad → `.strum`(+연결 유도) |

- **규칙: 화면 전환은 반드시 라우터로.** 뷰 안에서 직접 다른 화면을 띄우지 않기.
- 🗣️ *쉬운 설명: 건물 안내데스크. 모든 이동은 데스크를 거친다. 그래야 "그 화면 어떻게 여는 거예요?"라는 질문이 사라진다.*

#### ✅ 구현 완료 (2026-07-20, 태스크 F3)

- `App/AppRouter.swift` — `AppRoute`(9개) · `navigate/back/replaceRoot` · 시작 규칙 · `OnboardingStore`
- `App/AppRootView.swift` — **화면을 그리는 유일한 곳.** U 레인은 여기서 자기 case 한 줄만 바꾸면 된다
- 아직 안 만든 화면 4개는 `ScreenPlaceholder`가 자리를 잡고 있다 (담당 태스크 번호가 화면에 표시됨)

> 🛠️ **화면 개발 단축키:** 실행 인자 `-startRoute <이름>`을 주면 그 화면으로 바로 뜬다.
> 매번 클릭해서 들어갈 필요가 없다.
> ```
> Xcode  → Scheme → Run → Arguments에  -startRoute progressionCustom
> 명령줄 → xcrun simctl launch <device> <bundle-id> -startRoute peerGuide
> ```
> 이름은 `AppRoute`의 case 이름 그대로 (`onboarding`, `neck`, `strum`, `strokeSelect`,
> `strokeCreate`, `progressionSelect`, `progressionCustom`, `peerGuide`, `peerBrowse`). DEBUG 빌드 전용.

> ⚠️ **프로토타입 다리 (임시):** 넥·스트럼은 아직 프로토타입 화면 하나에 같이 들어 있고,
> 그 화면은 자체 `screen` 값으로 이동한다. `AppRootView`가 그걸 라우터 이동으로 옮겨주고 있다.
> **U2(넥)·U3(스트럼)가 완성되면 이 다리와 `Features/Shared/` 폴더 전체가 사라진다.**

### 3.10 온보딩·시스템 안내 [새로] — Features/Onboarding + Domain

| 항목 | 명세 |
|------|------|
| `OnboardingStore` | `hasCompletedOnboarding` (`UserDefaults`) — 완료 시 이후 자동 스킵 |
| `SystemSetupHelper` | 현재 볼륨 읽기(`AVAudioSession.outputVolume`), 볼륨 슬라이더 제공(`MPVolumeView` SwiftUI 래핑), "볼륨 낮음" 판정 |
| 연주 화면 공통 | 진입 시 `isIdleTimerDisabled = true`(화면 꺼짐 방지), 이탈 시 해제 |

- iOS에서 뭐가 되고 안 되는지는 **SPEC §플로우 4 표**가 기준 (볼륨 강제 설정 ❌ / 방해금지 켜기 ❌ → 안내로 해결).

### 3.11 손맛(햅틱·피드백) [보강] — Services/Haptics + UI

**책임:** 줄을 튕기고 코드를 짚는 **물리적 손맛**을 햅틱·시각으로 준다. 가상 악기의 "진짜 같음"은 소리만이 아니라 **손끝 진동**에서 온다 — 이게 없으면 그냥 유리판 두드리는 느낌이 된다. `HapticsManager`는 **이미 있으나 아직 아무 데도 연결 안 됨**(놓쳤던 부분).

| 기능 | 명세 |
|------|------|
| 발음 햅틱 | `notePlayed`/`strumPerformed` 이벤트(§3.4·§3.5) 구독 → **세기(velocity)에 비례**한 햅틱 |
| 감쇠 햅틱 | 튕긴 순간 강 → 서서히 약. **`UIImpactFeedbackGenerator`로는 불가** → **Core Haptics**(`CHHapticEvent .continuous` + `CHHapticParameterCurve`)로 승격 필요 |
| 판정 햅틱 | 목표 코드와 다른 운지 → 강한 진동. `currentFingering`(§3.4) vs 카탈로그 운지(§3.3) 비교 로직 필요 |
| 짝 개발 | 줄 애니메이션(U3)과 **같은 이벤트**를 먹으므로 함께 설계 |

- 🗣️ *쉬운 설명: 진짜 기타는 튕기면 손이 울린다. 그 울림을 흉내 내야 화면이 악기처럼 느껴진다.*
- ⚠️ **iPad는 햅틱 하드웨어가 없음** — 모드 C(긁는 기기=iPad)에서의 대체 피드백은 SPEC §8 결정 안건.
- 📌 음성 명령을 뺀 뒤 **접근성의 주인공**이 된 영역입니다 ([LEARNING-AREAS §5](LEARNING-AREAS.md)).

> 🗑️ **3.12 `VoiceCommandService` — 삭제됨 (2026-07-20).** 음성 명령 기능을 범위에서 제외하기로 결정했습니다 (에코 리스크 + 접근성 축을 햅틱으로 일원화). SPEC §5 결정 기록 참고. **§3.12를 참조하던 태스크(C8·V1~V3)도 함께 삭제**됐습니다.

---

## 4. 병렬 개발이 실제로 어떻게 돌아가나

### 4.1 규칙: "계약을 만들 때 Mock도 같이 만든다"

> **Mock이란?** 진짜처럼 생겼지만 속은 가짜인 대역 배우. 계약(껍데기)은 똑같이 지키므로, 진짜가 완성되면 **한 줄만 바꿔** 갈아끼운다.

이미 프로젝트에 표본이 있습니다 — `Services/Sound/MockSoundPreviewService.swift` (진짜 오디오 대신 시스템 효과음으로 대체). **모든 계약(§3.2~3.10)은 정의하는 사람이 Mock 1개를 같이 만드는 것이 산출물 조건입니다** (ROADMAP Phase 1).

예시:
- `MockStrumPatternLibrary` — 하드코딩 프리셋 3개 반환 → **스트로크 선택 화면을 진짜 로직 없이 완성 가능**
- `MockProgressionPlayer` — 3초마다 코드가 바뀌는 척 → **모드 B 화면을 진짜 플레이어 없이 개발**
- `MockFingeringState` — 어떤 터치든 C코드라고 응답 → **넥 UI를 로직 없이 개발**

### 4.2 계약별 생산자/소비자 매트릭스

| 계약 | 만드는 사람(생산) | 쓰는 사람(소비) | 소비자는 뭘로 먼저 개발? |
|------|-----------------|----------------|----------------------|
| 3.2 BeatClock | 로직 | 플레이어들 | 고정 간격 Mock 클럭 |
| 3.3 ChordCatalog | 로직(계약)+리서치(데이터) | 넥·진행 화면, 플레이어 | 기존 7개 코드로 충분 |
| 3.4 FingeringState | 로직 | 넥 UI, 코디네이터, 통신 | Mock 상태 |
| 3.5 StrumPattern | 로직(계약)+리서치(데이터) | 선택 화면, 모드 A | Mock 라이브러리 |
| 3.6 Progression | 로직(계약)+리서치(데이터) | 선택·커스텀 화면, 모드 B | Mock 라이브러리·플레이어 |
| 3.7 Session | 로직 | 메인 화면들 | 소스 Mock 2개 |
| 3.8 Peer 보강 | 통신 | 연결 화면, 원격 소스 | ConnectionFlowState만 있으면 UI 가능 |
| 3.9 Router | 기반 담당 | **전원** | — (제일 먼저 완성) |
| 3.10 Onboarding | 기반 담당 | 온보딩 화면 | — |
| 3.11 Haptics | 접근성 담당 | 넥·스트럼 화면 | `notePlayed` 이벤트만 있으면 가능 |

### 4.3 시나리오로 보는 병렬 (예: 진행 커스텀 화면, 화면 7)

1. 계약 §3.6이 Mock과 함께 완성됨 (반나절)
2. **동시에 출발:** 화면 담당은 Mock으로 UI 전부 구현 / 로직 담당은 진짜 플레이어·미리듣기 구현 / 리서치 담당은 머니코드·캐논 진행을 `Content/`에 입력
3. 각자 끝나면 Mock → 진짜로 교체 (init 인자 한 줄) → 끝

---

## 5. 전 팀 공통 규약 (헷갈리면 여기)

| 항목 | 규약 |
|------|------|
| 줄 번호 | `stringIndex 0 = 6번줄(저음 E)` … `5 = 1번줄(고음 E)`. 개방현 MIDI = `[40, 45, 50, 55, 59, 64]` |
| 프렛 값 | `-1 = 뮤트(X)` · `0 = 개방현` · `1~24 = 프렛` |
| 세기 | `velocity: UInt8` 0~127 (실사용 42~124로 클램프됨) |
| 스트럼 방향 | `.down = 6번줄→1번줄(저음→고음)` · `.up = 반대` |
| 박 위치 | `BeatPosition { bar(0부터), beat(0부터), sub(16분음표, 0~3) }` |
| 화면 전환 | 반드시 `AppRouter` 경유 |
| 색·여백 | 반드시 `DesignSystem/Tokens/` — 숫자 직접 쓰기 금지 |
| 계약 변경 | 계약 파일을 바꾸면 **팀 공지 + 이 문서 갱신** 필수 |
