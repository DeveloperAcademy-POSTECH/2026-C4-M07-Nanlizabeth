protocol SoundPreviewServiceProtocol {
    func playMockStrum(direction: StrumDirection)
    func playMockChord(_ chord: GuitarChord?)
}
