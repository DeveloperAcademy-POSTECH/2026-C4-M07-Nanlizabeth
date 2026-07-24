//
//  ChordlyApp.swift
//  Chordly
//
//  Created by Park on 7/13/26.
//

import SwiftUI

@main
struct ChordlyApp: App {
    // ⚠️⚠️ 유저 테스트 전용 임시 코드 — develop 반영 금지 (test/always-show-onboarding 브랜치에서만 산다).
    // 앱을 켤 때마다 온보딩·튜토리얼 "봤음" 플래그를 지워, 콜드 런치할 때마다 "처음 켠 것처럼"
    // 온보딩 → 튜토리얼이 다시 뜨게 한다. 재설치 없이 반복 테스트하려는 목적.
    // 키 출처: OnboardingStore("onboarding.hasCompleted"), TutorialStore("tutorial.hasSeen").
    init() {
        UserDefaults.standard.removeObject(forKey: "onboarding.hasCompleted")
        UserDefaults.standard.removeObject(forKey: "tutorial.hasSeen")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
