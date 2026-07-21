# 햅틱: "툭 한 번"에서 "서서히 잦아드는 떨림"으로

> 이 문서는 "왜 햅틱이 중요한가"(그건 [SPEC §5](../SPEC.md))가 아니라 **"진동을 실제로 어떻게 만드나"**를 설명하는 참고 자료입니다.
> 손맛(햅틱)은 음성 명령을 뺀 뒤 **접근성의 주인공**입니다 → 학습 관점은 [LEARNING-AREAS §5](../LEARNING-AREAS.md).

## 두 단계의 진동

| 단계 | 무엇 | 한계 |
|------|------|------|
| `UIImpactFeedbackGenerator` | **툭 한 번** 치는 진동. 세기(intensity)는 조절되지만 **시간에 따라 변하진 않는다** | 실제 기타 줄처럼 "서서히 잦아드는" 걸 못 만든다 |
| **Core Haptics** (`CHHapticEngine`) | **이어지는 진동에 곡선을 씌운다** — 강하게 시작해 0으로 끌어내리는 감쇠 | 지원 기기에서만. 시뮬레이터엔 진동 하드웨어가 없어 안 뜬다 |

## 감쇠 진동은 어떻게 만드나 (`DecayHapticPlayer`)

진짜 기타 줄은 튕긴 순간 강하게 떨리다 서서히 잦아든다. 이걸 흉내 내려면 **연속 이벤트 + 감쇠 곡선**이 필요하다.

```
CHHapticEvent(.hapticContinuous, duration: 0.5)   // 0.5초 동안 이어지는 진동
   +
CHHapticParameterCurve(.hapticIntensityControl)   // 강도를 시간에 따라 끌어내리는 곡선
   [t=0 → 1.0] ──▶ [t=0.25·dur → 0.6] ──▶ [t=dur → 0.0]
```

- 세게 칠수록(velocity ↑) **시작 강도(peak)가 높고 여운(duration)도 길다.**
- `UIImpactFeedbackGenerator`로는 이 "시간에 따라 변하는 곡선"을 못 그린다 — 그래서 Core Haptics로 올라간 것.
- Core Haptics 미지원 기기·시뮬레이터에서는 조용히 `UIImpactFeedbackGenerator`로 폴백한다(감쇠는 못 주지만 세기는 반영).

### 함정: 엔진이 멈추면 되살려야 한다

`CHHapticEngine`은 앱 백그라운드·오디오 세션 변화·기기 연결 리셋 등으로 **조용히 멈춘다.** 안 되살리면 다음부터 감쇠 진동이 안 나고 약한 폴백만 남는다("연결 끊었다 다시 하면 진동이 한 번 약하게만 오던" 증상). 그래서 **재생 직전마다 엔진이 돌고 있는지 확인해 필요하면 켜고**(`isAutoShutdownEnabled` + `ensureStarted`), 그래도 실패하면 한 번 되살려 재시도한다.

## 세 종류의 햅틱

| 종류 | 언제 | 어디서 트리거 |
|------|------|--------------|
| **발음 햅틱** (H1) | 줄이 울릴 때 세기별 진동 | `notePlayed` 이벤트 구독 (`NotePlayedHaptics`) — **줄 애니메이션과 같은 이벤트** |
| **판정 햅틱** (H3) | 목표와 다른 코드를 짚으면 "아니야" 진동 | 짚은 운지 vs 목표 코드 비교(`ChordJudge`) → 틀리면 오류 진동 |
| **감쇠 햅틱** (H2) | 위 진동을 "서서히 잦아들게" | `DecayHapticPlayer` (위 설명) |

> 발음 햅틱이 **줄 애니메이션(U3)과 똑같은 `notePlayed`를 먹는다**는 게 설계의 핵심 — 손끝(진동)과 눈(줄 떨림)이 한 신호에서 갈라진다.

## 모드 C에서의 햅틱 방향 — 손맛은 "튕기는 쪽"에서 난다

두 기기 합주(모드 C)에선 진동을 누가 언제 느끼냐가 뒤집힌다.

- **iPhone(짚는 쪽)** — 코드를 짚어도 **진동 안 함**(짚기 자체는 손맛이 아니다). 시각적 줄 떨림만 준다.
- **iPad(긁는 쪽)** — 튕길 때마다 그 **세기를 iPhone으로 전송**(`strumHaptic` 메시지).
- **iPhone이 그 신호를 받아 진동한다** — 실제로 줄이 튕겨 손맛이 생기는 건 오른손(iPad)이지만, iPad는 햅틱 하드웨어가 약하므로 **진동은 iPhone에서** 느끼게 한다.

> ⚠️ **iPad는 햅틱 하드웨어가 없다시피 하다** — 그래서 진동을 iPhone으로 보내는 이 구조가 나왔다. 어디에 어떤 피드백을 줄지는 원래 SPEC §8 열린 결정이었고, 지금 구현은 "iPhone에서 느끼게"로 정한 것.

## 볼 파일

| 파일 | 역할 |
|------|------|
| `Services/Haptics/HapticsManager.swift` | 세기별 단발 진동(`UIImpactFeedbackGenerator`) · 오류 진동 |
| `Services/Haptics/DecayHapticPlayer.swift` | Core Haptics 감쇠 진동 + 엔진 복구 |
| `Services/Haptics/NotePlayedHaptics.swift` | `notePlayed` 구독 → 세기별 진동(짧은 창에서 합침) |
| `Domain/Fingering/ChordJudge.swift`·`ChordJudgmentController.swift` | 판정 햅틱의 비교 로직 |
