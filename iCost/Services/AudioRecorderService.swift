import Foundation
import AVFoundation

@MainActor
final class AudioRecorderService: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var deadlineTimer: Timer?
    var onMeterUpdate: ((Float) -> Void)?
    var onFinish: ((URL?) -> Void)?

    func start(maxDuration: TimeInterval = 60) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        let url = FilePaths.audioFileURL()
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.delegate = self
        recorder?.record()
        meterTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(handleMeterTimer), userInfo: nil, repeats: true)
        deadlineTimer = Timer.scheduledTimer(timeInterval: maxDuration, target: self, selector: #selector(handleDeadlineTimer), userInfo: nil, repeats: false)
    }

    func stop() {
        meterTimer?.invalidate()
        deadlineTimer?.invalidate()
        meterTimer = nil
        deadlineTimer = nil
        recorder?.stop()
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let url: URL? = flag ? recorder.url : nil
        Task { @MainActor in
            self.onFinish?(url)
        }
    }

    @objc private func handleMeterTimer() {
        guard let r = recorder else { return }
        r.updateMeters()
        let power = r.averagePower(forChannel: 0)
        let level = max(0, min(1, (power + 60) / 60))
        onMeterUpdate?(level)
    }

    @objc private func handleDeadlineTimer() {
        stop()
    }
}
