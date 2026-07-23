# 계획/구현 — 넥 포지션 이동 (사운드홀 쪽 프렛 짚기)

> 지금 넥은 **너트(튜닝 손잡이) 근처 1~5프렛까지만** 짚을 수 있다. 사운드홀 쪽 높은 프렛도 짚게
> 하되, **입력 방식을 인터페이스로 빼서 슬라이더 버전과 코어모션 버전을 A/B 비교**한다.

---

## 1. 문제와 목표

- **문제:** 화면 넥이 프렛 5칸(1~5프렛)만 보여줘, 사운드홀에 가까운 높은 프렛을 못 짚는다.
- **목표:** 화면 첫 칸이 몇 프렛인지(**포지션 오프셋**)를 움직여 넥을 사운드홀 쪽으로 옮긴다.
- **핵심 설계:** 오프셋을 정하는 **입력 방식**을 인터페이스(`NeckPositionProviding`)로 빼고,
  ① 슬라이더 ② 코어모션 두 구현을 꽂아 A/B로 무엇이 더 좋은 경험인지 비교한다.

## 2. 어디까지 짚게 하나 — 최고 12프렛

어쿠스틱 기타는 **넥이 몸통(사운드홀)과 12~14프렛 근처에서 만난다.** 코드/음을 실제로 짚는
영역도 대략 0~12프렛(한 옥타브)이다. 그래서 **최고 12프렛**까지로 정했다
(`ChordModeController.maxFret = 12`). 화면 창은 5칸이므로 **오프셋 0~7**
(창: 1–5 · 2–6 · … · 8–12). 값 하나만 바꾸면 조정된다.

## 3. 동작 방식 — 화면 점은 그대로, 소리는 오프셋 프렛으로

넥 그림·짚은 점은 **화면 좌표(1~5칸) 그대로** 두고, 소리·운지만 **오프셋을 더한 실제 프렛**으로 낸다.

- `NeckViewModel.activePresses` = 화면 좌표(그리기용) · `fingeringState`엔 `+fretOffset`한 프렛 전달.
- 개방현(0)엔 오프셋을 안 더한다 — 카포가 아니라 포지션 이동이므로 안 짚은 줄은 그대로 개방.
- 포지션 > 0이면 넥 오른쪽(너트 옆)에 **`Nfr` 배지**로 지금 첫 칸이 몇 프렛인지 표시.

## 4. 아키텍처 (인터페이스 + 두 구현)

```
NeckPositionProviding (프로토콜)  ── positionChanged ──▶ ChordModeController ──▶ NeckViewModel.setFretOffset
   ├─ SliderNeckPositionProvider   (🎚️ 화면 슬라이드바)
   └─ MotionNeckPositionProvider   (📱 코어모션 기울기)
```

| 파일 | 역할 |
|---|---|
| `Domain/Fingering/NeckPositionProviding.swift` | 프로토콜 + `NeckPositionMode`(A/B) + 슬라이더 구현 |
| `Services/Motion/MotionNeckPositionProvider.swift` | 코어모션 구현 (기울기→포지션) |
| `Features/Neck/NeckViewModel.swift` | `fretOffset` 보유, 짚기에 오프셋 적용 |
| `Features/Neck/NeckScreen.swift` | 포지션 배지 + 컨트롤 제외영역(`extraExcludedRegions`) |
| `Features/Neck/ChordModeController.swift` | 두 공급자 소유 + A/B 전환 + 넥에 배선 |
| `Features/Shared/MainInstrumentScreen.swift` | 포지션 컨트롤(슬라이더+토글) UI 배치 |

**모드 A(자유연주)에만 적용.** 코드 드릴은 목표가 열린 코드라 오프셋 0 고정(영향 없음).

## 5. 코어모션에서 고려한 것 (좋은 기타 경험)

- **중립 기준:** `start()` 시점 기울기를 0프렛으로 잡아, 어떤 자세로 들든 그 자리가 시작점.
- **떨림 억제:** 각도 저역통과(smoothing) + 칸 경계 **히스테리시스**로 딸깍딸깍 튐 방지.
- ⚠️ iPhone은 세로 고정 + 콘텐츠 -90° 회전이라, "넥 방향 기울임" 축·부호는 **실기기 조정 필요**.

## 6. 남은 고민 (열린 결정)

- **슬라이더를 언제 보여줄지:** 지금은 넥 아래(줄보다 밑, 터치 제외영역)에 **항상 표시**.
  자리를 많이 차지하지 않지만, "필요할 때만 펼치기"(토글)로 바꾸는 것도 후보 — A/B 후 결정.
- **모션 감도·축:** 실기기에서 `travelAngle`·`smoothing`·`hysteresis`와 축 선택을 맞춰야 자연스럽다.
- **높은 프렛 배경:** 배경 이미지는 1~5프렛 고정이라, 오프셋 시 인레이(3·5프렛)는 그림과 어긋난다.
  현재는 `Nfr` 배지로 보완. 필요하면 스크롤형 넥 이미지로 확장.

## 7. 검증

- **유닛테스트(가능):** `SliderNeckPositionProvider` 클램프, `NeckViewModel.shifted`(오프셋 적용/개방현 제외).
- **실기기(필수):** 슬라이더로 6fr 이동 후 짚으면 그 프렛 소리가 나는지 · 배지 표시 · 모션 감도 ·
  포지션 바가 프렛 짚기와 안 겹치는지.
