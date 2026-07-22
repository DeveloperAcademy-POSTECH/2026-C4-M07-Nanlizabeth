# 계획 — 코드 전환 드릴 (Chord Transition Drill)

> iPhone 왼손(넥) 단독 연습에 얹는 새 서브모드.
> **정답 코드를 짚었을 때만 소리가 난다.** 소리가 곧 "맞았다"는 피드백이고, 소리를 내려는 동기가
> 올바른 운지를 빠르게 찾게 만든다 — 그 반복이 왼손 코드 전환을 근육기억으로 남긴다.

---

## 1. 배경 (왜 만드나)

이 앱은 실제 기타의 왼손 운지를 100% 재현하지 못한다(터치 지판엔 장력·손가락 번호·소리 죽음이 없다).
그래도 **초보자가 가장 자주 막히는 지점 하나 — "코드를 빠르게 바꿔 짚기" — 만큼은** 앱으로 해결해줄 수 있다.

- 목표 코드를 하나 제시한다 → 유저가 그 모양을 정확히 짚으면 **그제서야 소리가 난다.**
- 틀린 모양은 **무음.** 소리를 나게 하려면 올바른 폼을 찾아야 하므로, 무음 자체가 교정 피드백이 된다.
- 맞히면 **즉시 다음 코드**로 넘어간다. C→G→Am→F 같은 프리셋 진행을 순서대로 돌며
  "이 코드 다음엔 이 손동작"을 몸이 외우게 한다.

이건 **연주법을 가르치는 튜토리얼이 아니다**(SPEC §8 비목표와 충돌하지 않음). 정답이 있는
**연습·피드백 모드**다. 실제 기타 수준의 운지 정확도를 요구하지 않고, "짚는 자리"만 본다(§5 참고).

**적용 범위:** iPhone 단독 = **모드 A 위에 얹는 서브모드**. iPad·멀티피어 연결(모드 C)은 이번 범위 밖.

---

## 2. 한 줄 정의 & 사용자 흐름

> **정답 코드일 때만 자동 스트럼이 소리를 내는, 프리셋 진행을 순서대로 도는 왼손 코드 전환 드릴.**

```
[화면 진입]
  ├─ 목표 HUD: "C"  · 진행 표시 ●○○○
  ├─ 자동 스트럼이 BPM대로 계속 긁는다 (모드 A와 동일)
  │
[유저가 넥을 짚는다]
  ├─ 틀린 모양 → 스트럼이 긁어도 **무음** (게이트 닫힘)
  ├─ 정답 모양(안정적으로) → 다음 스트럼이 그 코드를 **울린다** = 보상
  │                          + 정답 햅틱/플래시
  └─ → 목표가 다음 코드로: "G" · ●●○○
  ...(진행 끝나면 처음으로 루프)
```

시간 압박 없음(자기 페이스). 맞힐 때까지 목표는 그대로 있고, 계속 무음일 뿐이다.

---

## 3. 이미 있는 것 (재사용 — 새로 만들지 않는다)

이 기능에 필요한 부품 대부분이 이미 코드에 있다. **없는 건 "소리 게이트"와 "드릴 진행 UI"뿐.**

| 필요한 것 | 이미 있는 것 | 위치 |
|---|---|---|
| 짚은 운지를 실시간으로 안다 | `FingeringState` (멀티터치 → `GuitarFingering`) | `Domain/Fingering/FingeringState.swift` |
| 짚은 운지 vs 목표 코드 판정 | `ChordJudge.judge(played:target:)` — 순수·관대(짚는 자리만) | `Domain/Fingering/ChordJudge.swift` |
| 목표 코드 슬롯 (아직 아무도 안 씀) | `ChordModeController.setTargetChord(_:)` — 정의만 있고 **호출부 없음** | `Features/Neck/ChordModeController.swift:76` |
| 짚기는 무음, 자동 스트럼이 소리 | `FretSoundPolicy.silent` + `AutoStrumSource` | `ChordPracticeSession.swift:47-66` |
| **소리가 나는 유일한 지점** | `PlaySession.handleStrum` / `handlePluck` | `Domain/Session/PlaySession.swift:156-202` |
| 프리셋 진행(머니코드 등) | `ChordProgressionLibrary` / 프리셋 데이터 | `Domain/Progression/`, `Content/ProgressionPresetData.swift` |
| 넥 렌더링(지판·짚은 점·줄 떨림) | `NeckScreen` + `NeckViewModel` | `Features/Neck/` |

**핵심 관찰(넥 탐색 결과):** `PlaySession.handleStrum`이 `fingeringSource.currentFingering`을 읽어
`audioEngine.strum(...)`을 부르는 **단일 초크포인트**다. 여기 한 줄만 게이팅하면 터치 처리·오디오 엔진을
건드리지 않고 모드 A 소리 전체를 제어할 수 있다.

---

## 4. 설계

아키텍처 규약(ARCHITECTURE §3.7 · ADR 0004)대로 **"모드 = 소스 조합 하나 추가"**. 기존
`ChordPracticeSession`의 형제로 조립하고, 소리 경로에 게이트 훅만 얹는다.

### 4-1. 소리 게이트 (핵심, 유일한 계약 변경)

`PlaySessionCoordinator`(`PlaySession.swift`)에 **선택적 게이트**를 추가한다:

```swift
// PlaySession 내부
var soundGate: ((GuitarFingering) -> Bool)? = nil   // nil = 항상 통과(기존 동작 그대로)

private func handleStrum(_ occurrence: StrumOccurrence) {
    let fingering = fingeringSource?.currentFingering ?? .open
    if let gate = soundGate, !gate(fingering) { return }   // ★ 닫히면 이 획은 무음
    audioEngine?.strum(frets: fingering.frets, ...)
    ...
}
```

- `handlePluck`에도 같은 가드. **기본값 `nil`이라 기존 모드 A·B·C는 무변화.**
- 드릴 세션이 `soundGate = { ChordJudge.matches($0.frets, target.fingering.frets) }`로 채운다.
- 판정은 **매 획 즉시** 평가(디바운스 없음) — 소리 반응이 즉각적이어야 한다. (아래 4-3의 진행 판정과
  다른 경로임에 유의: 진행은 안정화 후, 소리 게이트는 실시간.)

> ⚠️ `PlaySession.swift`는 계약성 파일이므로, 이 훅 추가는 팀 공지 + ARCHITECTURE §3.7 갱신 대상
> (ARCHITECTURE §규약). 게이트를 "값으로 뺀 정책"으로 두는 건 `FretSoundPolicy` 설계와 같은 결.

### 4-2. 드릴 진행 상태 — `ChordDrill`

```swift
struct ChordDrill {                 // Domain/Session/ 또는 Domain/Progression/
    let sequence: [GuitarChord]     // 프리셋 진행 재사용 (예: [C, G, Am, F])
    private(set) var index = 0
    var current: GuitarChord { sequence[index] }
    mutating func advance() { index = (index + 1) % sequence.count }   // 끝나면 루프
}
```

시퀀스는 **새 콘텐츠를 만들지 않고** `ChordProgressionLibrary`의 프리셋(머니코드 C→G→Am→F, 캐논)을
그대로 쓴다. 현재 카탈로그 8개 코드(C·D·E·G·A·Am·Em·F)로 머니코드·캐논 모두 커버된다.

### 4-3. 세션 — `ChordDrillSession` (`ChordPracticeSession`의 형제)

`Domain/Session/ChordDrillSession.swift`. `ChordPracticeSession`을 본떠 조립하되:

- `FingeringState(soundPolicy: .silent)` + `AutoStrumSource` → 기존과 동일(짚기 무음, 자동 스트럼).
- `coordinator.soundGate`를 현재 목표에 묶는다.
- `drill`을 들고, 목표가 바뀌면 게이트가 참조하는 target도 갱신.

### 4-4. 컨트롤러 — `ChordDrillController` (`ChordModeController`의 형제)

`Features/Neck/ChordDrillController.swift`. 화면과 세션을 잇고 **정답 → 다음** 루프를 돈다:

- `session.fingeringState.fingeringChanged`를 구독, `ChordJudge.judge(played:target:)` 실행.
- 짧은 안정화(~0.3s settle, 만드는 도중 오판 방지) 후 `.correct`이면:
  1. 정답 피드백 — `HapticsManager.correctChord()`(신규) + 화면 플래시
  2. `drill.advance()` → 새 목표를 세션 게이트·화면 HUD에 반영
  3. 다음 획부터 새 목표로 게이팅
- `.incorrect`는 그냥 무음 유지(선택: `HapticsManager.wrongChord()`로 살짝 알림 — 접근성 플래그로 on/off).

> 기존 `ChordJudgmentController`(0.4s 디바운스, 오답 햅틱)는 **재사용하지 않는다.** 그건 자유연주용
> 오답 알림 경로다. 드릴은 "정답 → 진행"이 주 이벤트라 별도 컨트롤러가 깔끔하다. 단 **판정 자체는
> 같은 순수 함수 `ChordJudge`를 공유**한다(중복 로직 없음).

### 4-5. 화면 — `ChordDrillScreen` + `AppRoute.chordDrill`

- `Features/Neck/ChordDrillScreen.swift`: **`NeckScreen`을 그대로 품고**(지판·짚은 점·줄 떨림 재사용)
  위에 오버레이만 얹는다 — 목표 코드 HUD, 진행 표시(●○○○), 정답 플래시.
- 라우팅(ARCHITECTURE §라우터 규약): `AppRoute.chordDrill` 추가 →
  `isAvailable(on:)`에서 **iPad 제외**(왼손 화면은 iPhone 전용, `.neck`과 동일 취급) →
  `App/AppRootView.swift` `screen` switch에 렌더 분기 추가 → 넥 화면(또는 온보딩/메뉴)에서
  `router.navigate(to: .chordDrill)`로 진입.
- 숫자·색은 직접 쓰지 말고 `NeckGeometry`·`DesignSystem/Tokens` 사용(ARCHITECTURE §규약).

### 4-6. 손맛 — `HapticsManager.correctChord()` (신규)

`Services/Haptics/HapticsManager.swift`에 정답용 `.success` 노티피케이션 햅틱 추가
(현재 `wrongChord()`만 있음). iPhone 전용이라 iPad 햅틱 부재(SPEC §5.2) 이슈 없음.

---

## 5. 판정 규칙

MVP는 **기존 `ChordJudge`의 관대한 기준을 그대로 쓴다** — 짚는 프렛 자리만 비교하고, 뮤트(-1)와
개방(0)은 같은 "안 짚음"으로 본다(`ChordJudge.swift:44-55`). 이유:

- 코드의 정체성은 **짚는 자리**가 정한다. 저음줄을 정확히 죽이는 건 초보자에게 어렵다.
- 이 기능의 목적은 "빠른 전환 근육기억"이지 완벽한 뮤트 훈련이 아니다.

> 나중에 더 엄격하게(뮤트까지 채점) 하고 싶으면 `ChordJudge.fretClass`/`matches`만 조이면 된다 —
> 드릴 로직은 안 바뀐다. MVP 범위 밖.

---

## 6. 미해결 결정 해소 (SPEC §8)

이 기능은 문서에 열려 있던 결정 하나를 **정면으로 해소한다:**

- SPEC §8: *"모드 A엔 정답이 없다 — 판정을 어느 모드에서 켤지"* →
  **드릴은 "목표(정답)가 있는 별도 서브모드"로 도입한다.** 자유연주 모드 A(목표 없음, 아무 코드나
  자유롭게)는 **그대로 둔다.** 드릴은 그 위에 얹는 선택적 화면이다.
- SPEC §215에 이미 떠 있는 미구현 "모드 D(직접×직접)" 슬롯과 같은 계열의 신규 모드로 볼 수 있다 —
  모드가 신규 인터랙션의 단위라는 팀 컨벤션에 부합.

---

## 7. 파일 변경 목록

**신규**
- `Domain/Session/ChordDrill.swift` — 진행 상태(시퀀스·index·advance)
- `Domain/Session/ChordDrillSession.swift` — 세션 조립(게이트 포함)
- `Features/Neck/ChordDrillController.swift` — 정답→다음 루프
- `Features/Neck/ChordDrillScreen.swift` — NeckScreen + 목표 HUD·진행·플래시

**수정 (작게)**
- `Domain/Session/PlaySession.swift` — `soundGate` 훅 + `handleStrum`/`handlePluck` 가드 *(계약 변경 → 팀 공지 + ARCHITECTURE §3.7 갱신)*
- `App/AppRouter.swift` — `AppRoute.chordDrill` 케이스 + `isAvailable(on:)` iPad 제외
- `App/AppRootView.swift` — `screen` switch 렌더 분기
- `Services/Haptics/HapticsManager.swift` — `correctChord()` 추가
- 진입점(넥 화면 또는 온보딩/메뉴) — 드릴 진입 버튼 1개

**변경 없음(재사용):** `ChordJudge`, `FingeringState`, `NeckScreen`/`NeckViewModel`,
`ChordProgressionLibrary`, `ChordCatalog`, `AutoStrumSource`.

---

## 8. 콘텐츠

MVP는 **새 코드·새 시퀀스 없이** 시작 가능:
- 머니코드 `C→G→Am→F`, 캐논 진행 모두 현재 카탈로그 8코드로 커버됨.
- 프리셋 진행 재사용(`ChordProgressionLibrary`).

향후 확장 시 `Content/ChordCatalogData.swift`에 코드 한 줄씩 추가하면 자동 반영(리서치 CT3 흐름과 동일).

---

## 9. 구현 단계 (ROADMAP 레인 매핑)

작은 단위부터. 각 단계 끝에서 독립적으로 검증 가능.

1. **로직(L)** — `ChordDrill` + `ChordJudge` 조합 유닛테스트(진행·루프·판정). 화면 없이 검증.
2. **로직(L)** — `PlaySession.soundGate` 훅 + 가드. 기존 모드 회귀 없음 확인(게이트 nil).
3. **로직/조립(I)** — `ChordDrillSession` 조립. `MockBeatClock`으로 "정답만 소리" 검증.
4. **손맛(H)** — `HapticsManager.correctChord()`.
5. **화면(U)** — `ChordDrillScreen`(NeckScreen 재사용 + HUD) + `AppRoute` 배선 + 진입점.
6. **조립(I)** — `ChordDrillController` 정답→다음 루프 연결. **실기기 통합 테스트.**

---

## 10. 검증 (테스트 방법)

**유닛테스트 (시뮬레이터 가능)**
- `ChordDrill.advance()` 순서·루프.
- `ChordJudge`로 게이트 predicate: 정답 프렛→통과, 오답→차단, notAttempted→차단.
- `MockBeatClock`+`Mock` 엔진으로 `ChordDrillSession`: 목표와 다른 운지 유지 시 `audioEngine.strum` **미호출**, 정답 유지 시 호출.

**실기기 테스트 (필수 — 멀티터치는 시뮬레이터 검증 불가, ADR 0006 / ROADMAP U2)**
- iPhone에서 드릴 진입 → 목표 "C" 표시, 자동 스트럼 소리 안 남.
- 틀린 모양 짚기 → 계속 무음.
- C 정답 폼 → 소리 남 + 정답 햅틱/플래시 → 목표 "G"로 전환.
- 진행 끝까지 돌고 처음으로 루프.

---

## 11. 범위 밖 / 비목표

- **손가락 번호(검지·중지…) 지정·채점 없음** — 데이터에 손가락 정보 자체가 없다(짚는 자리만).
- **멀티피어 연결(모드 C) 미적용** — iPhone 단독만. (연결 시 정답일 때만 iPad로 운지 전송하는 확장은 후속.)
- **BPM·진행의 피어 간 동기화 없음** — 전부 로컬.
- **연주법 튜토리얼 아님** — 정답 피드백 드릴일 뿐(SPEC §8 비목표 유지).
- **엄격 뮤트 채점 없음(MVP)** — 관대한 `ChordJudge` 유지.
