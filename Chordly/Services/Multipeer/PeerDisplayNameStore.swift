import Foundation
import UIKit

/// 사용자가 정한 멀티피어 기기 이름. 앱을 다시 열어도 같은 이름으로 검색된다.
enum PeerDisplayNameStore {
    private static let key = "peer.customDisplayName"

    static var savedName: String? {
        let value = UserDefaults.standard.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    static var currentName: String {
        sanitized(savedName ?? UIDevice.current.name)
    }

    @discardableResult
    static func save(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let safeName = sanitized(trimmed)
        guard !safeName.isEmpty else { return nil }
        UserDefaults.standard.set(safeName, forKey: key)
        return safeName
    }

    /// `MCPeerID.displayName`의 63바이트 제한보다 여유 있게 UTF-8 60바이트로 맞춘다.
    private static func sanitized(_ value: String) -> String {
        var result = ""
        for character in value {
            let candidate = result + String(character)
            guard candidate.utf8.count <= 60 else { break }
            result = candidate
        }
        return result.isEmpty ? "Chordly" : result
    }
}
