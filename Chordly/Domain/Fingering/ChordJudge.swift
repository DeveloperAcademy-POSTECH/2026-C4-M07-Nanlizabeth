import Foundation

/// 지금 짚은 운지가 목표 코드와 맞는지 판정한다. (ROADMAP 태스크 H3 · SPEC §5.2 판정 햅틱)
///
/// **순수 계산이라 화면·햅틱 없이 검증된다.** 진동을 언제 줄지는 `ChordJudgmentController`가,
/// 실제 진동은 `HapticsManager`가 맡는다 — 여기선 "맞나 틀리나"만 답한다.
///
/// ## 판정 규칙 — 초보자에게 관대하게
///
/// **짚는 프렛(1 이상)이 목표와 같으면 맞은 것**으로 친다. 뮤트(-1)와 개방현(0)의 차이는 봐준다 —
/// 저음줄을 정확히 죽이는 건 초보자에게 어렵고, 코드의 정체성은 **짚는 자리**가 정하기 때문이다.
///
/// ```
/// 목표 C = [-1, 3, 2, 0, 1, 0]
/// 짚음   = [ 0, 3, 2, 0, 1, 0]   → 맞음 (6번줄 뮤트를 개방으로 친 것만 다름)
/// 짚음   = [ 3, 2, 0, 0, 0, 3]   → 틀림 (G코드 — 짚는 자리가 다름)
/// ```
enum ChordJudge {
    enum Result: Equatable {
        /// 목표와 (관대한 기준으로) 일치.
        case correct
        /// 짚는 자리가 다르다.
        case incorrect
        /// 판정할 만큼 짚지 않았다 (거의 빈손) — 진동을 주지 않는다.
        case notAttempted
    }

    /// 짚는 프렛이 하나라도 있어야 "시도"로 본다. 이보다 적으면 아직 만드는 중이라 판정 보류.
    private static let minimumFrettedForAttempt = 1

    static func judge(played: GuitarFingering, target: GuitarFingering) -> Result {
        let playedFretted = played.frets.filter { $0 >= 1 }.count
        guard playedFretted >= minimumFrettedForAttempt else { return .notAttempted }

        return matches(played: played.frets, target: target.frets) ? .correct : .incorrect
    }

    /// 코드로 목표를 지정하는 편의 오버로드.
    static func judge(played: GuitarFingering, target: GuitarChord) -> Result {
        judge(played: played, target: target.fingering)
    }

    /// **짚는 자리**만 비교한다. 뮤트·개방은 둘 다 "안 짚음"으로 같게 본다.
    static func matches(played: [Int], target: [Int]) -> Bool {
        guard played.count == target.count else { return false }
        let normalizedPlayed = applyingBarreAllowance(to: played, target: target)
        if isGVariant(normalizedPlayed), isGVariant(target) {
            return true
        }
        for (p, t) in zip(normalizedPlayed, target) where fretClass(p) != fretClass(t) {
            return false
        }
        return true
    }

    /// 노래 연습의 반주를 빠르게 여는 초보자 보조 판정.
    ///
    /// 틀린 프렛은 하나도 없어야 한다. 다만 세 자리 이상을 짚는 코드는 마지막 한 손가락이
    /// 올라오는 동안에도 목표 자리의 나머지가 완성됐으면 반주를 시작한다.
    static func matchesForAssistedPlayback(played: [Int], target: [Int]) -> Bool {
        guard played.count == target.count else { return false }
        if matches(played: played, target: target) {
            return true
        }

        let normalizedPlayed = applyingBarreAllowance(to: played, target: target)
        let targetFrettedStrings = target.indices.filter { fretClass(target[$0]) > 0 }
        guard !targetFrettedStrings.isEmpty else { return false }

        let hasWrongFret = played.indices.contains { index in
            let playedFret = fretClass(normalizedPlayed[index])
            return playedFret > 0 && playedFret != fretClass(target[index])
        }
        guard !hasWrongFret else { return false }

        let correctlyFrettedCount = targetFrettedStrings.count { index in
            fretClass(normalizedPlayed[index]) == fretClass(target[index])
        }
        let requiredCount = targetFrettedStrings.count >= 3
            ? targetFrettedStrings.count - 1
            : targetFrettedStrings.count
        return correctlyFrettedCount >= requiredCount
    }

    private static func isGVariant(_ frets: [Int]) -> Bool {
        let normalized = frets.map { $0 <= 0 ? 0 : $0 }
        return normalized == [3, 2, 0, 0, 0, 3]
            || normalized == [3, 2, 0, 0, 3, 3]
    }

    /// 목표 코드가 같은 프렛을 넓게 바레로 잡는 형태라면, 그 범위의 양 끝 현을 눌렀을 때
    /// 사이의 같은 프렛 현도 눌린 것으로 인정한다. 화면 가장자리의 1번 현 대신 바로 안쪽 2번 현을
    /// 눌러도 바레 끝으로 인정한다. 다른 손가락으로 더 높은 프렛을 누른 현은 그대로 유지한다.
    private static func applyingBarreAllowance(to played: [Int], target: [Int]) -> [Int] {
        var normalized = played
        let frettedGroups = Dictionary(grouping: target.indices.filter { target[$0] >= 1 }) { target[$0] }

        for (fret, strings) in frettedGroups where strings.count >= 2 {
            guard let first = strings.min(),
                  let last = strings.max(),
                  target[first...last].allSatisfy({ $0 >= fret }),
                  fretClass(played[first]) == fret
            else { continue }

            var trebleEndpoints = [last]
            if last > first, target[last - 1] == fret {
                trebleEndpoints.append(last - 1)
            }
            guard trebleEndpoints.contains(where: { fretClass(played[$0]) == fret }) else { continue }

            for stringIndex in first...last {
                normalized[stringIndex] = max(fretClass(normalized[stringIndex]), fret)
            }
        }

        return normalized
    }

    /// 뮤트(-1)와 개방현(0)을 같은 "안 짚음"으로 묶는다. 프렛은 그대로.
    private static func fretClass(_ fret: Int) -> Int {
        fret <= 0 ? 0 : fret
    }
}
