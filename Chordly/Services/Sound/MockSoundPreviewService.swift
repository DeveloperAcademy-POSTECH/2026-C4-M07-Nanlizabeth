import AudioToolbox

final class MockSoundPreviewService: SoundPreviewServiceProtocol {
    func playMockStrum(direction: StrumDirection) {
        AudioServicesPlaySystemSound(direction == .down ? 1104 : 1105)
    }

    func playMockChord(_ chord: GuitarChord?) {
        AudioServicesPlaySystemSound(1057)
    }
}
