import SwiftUI

/// 화면 8 — 연결 가이드. (SPEC 플로우 3 / ARCHITECTURE §3.8 · ROADMAP 태스크 U7)
///
/// ## 만들 때 챙길 것
/// - **스킵 가능**해야 한다. 스킵도 "봤음"으로 쳐서 `PeerGuideStore.markGuideSeen()`을 부른다
///   → 다음부터는 연결 버튼이 바로 기기 찾기로 간다.
/// - ⚠️ **로컬 네트워크 권한 팝업을 미리 예고**한다. 첫 연결 때 iOS가 띄우는 시스템 팝업이라
///   우리가 없앨 수 없다. "이런 팝업이 뜨면 허용을 눌러주세요"라고 알려준다.
/// - ⚠️ 그 팝업은 **스테이지 회전을 따라오지 않아 옆으로 보인다** → ARCHITECTURE §2.5 예외 처리.
struct PeerGuideScreen: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ScreenPlaceholder(
            route: .peerGuide,
            task: "U7",
            hint: "단계별 안내 + 권한 팝업 예고 + 스킵 버튼"
        )
    }
}

/// 화면 9 — 근처 기기 찾기. (SPEC 플로우 3 / ARCHITECTURE §3.8 · ROADMAP 태스크 U7)
///
/// ## 만들 때 챙길 것
/// - 화면은 **`ConnectionFlowState`만 보고 그린다** (idle/browsing/inviting/connected/…).
///   Multipeer 내부 사정을 화면이 알 필요가 없다.
/// - **역할은 협상하지 않는다** — `PeerRolePolicy.role(for:)`로 기기 종류에서 바로 정해진다.
///   iPad는 항상 스트로크, iPhone은 항상 코드.
/// - 통신 자체(`MultipeerService`)는 이미 동작한다. 상태 표시와 연결만 붙이면 된다.
struct PeerBrowseScreen: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ScreenPlaceholder(
            route: .peerBrowse,
            task: "U7",
            hint: "탐색·초대·연결 상태 (ConnectionFlowState 기반)"
        )
    }
}
