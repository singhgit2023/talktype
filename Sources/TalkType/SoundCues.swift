import AppKit

@MainActor final class SoundCues {
    private let start = SoundCues.load("start-pop")
    private let finish = SoundCues.load("finish-pop")

    func playStart() {
        start?.stop()
        start?.play()
    }

    func playFinish() {
        finish?.stop()
        finish?.play()
    }

    private static func load(_ name: String) -> NSSound? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        let sound = NSSound(contentsOf: url, byReference: true)
        sound?.volume = 0.16
        return sound
    }
}
