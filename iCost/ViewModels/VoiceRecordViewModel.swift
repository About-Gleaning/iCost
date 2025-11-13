import Foundation
import SwiftData

@MainActor
final class VoiceRecordViewModel: ObservableObject {
    enum Status { case idle, recording, processing, done, failed(String) }
    @Published var status: Status = .idle
    @Published var waveform: [Float] = []
    @Published var transcript: String = ""
    @Published var amountText: String = ""
    @Published var category: Category = Category.other
    @Published var note: String = ""

    private let recorder = AudioRecorderService()
    private let speech = SpeechService()
    private let parser: any BillParser = QwenBillParser()
    private var recordedURL: URL?

    func startRecording() {
        status = .recording
        recorder.onMeterUpdate = { [weak self] level in
            DispatchQueue.main.async { self?.appendWave(level) }
        }
        recorder.onFinish = { [weak self] url in
            DispatchQueue.main.async { self?.recordedURL = url; self?.status = .processing }
        }
        do { try recorder.start(maxDuration: 60) } catch { status = .failed("录音失败") }
    }

    func stopRecording() { recorder.stop() }

    func analyzeAudioAndSave(context: ModelContext) async {
        guard let url = recordedURL else { return }
        do {
            print("Parser: prepare audio call url=\(url.path)")
            let parsed = try await parser.parseAudio(url: url)
            amountText = String(format: "%.2f", parsed.amount)
            category = parsed.category
            note = parsed.note
            print("Parser: parsed amount=\(parsed.amount) category=\(parsed.category.rawValue) note=\(parsed.note)")
            saveBill(context: context)
        } catch {
            status = .failed("解析失败")
            print("Parser: error=\(error.localizedDescription)")
        }
    }

    

    func saveBill(context: ModelContext) {
        let amount = Double(amountText) ?? 0
        var audioPath: String? = recordedURL?.path
        if let url = recordedURL, let data = try? Data(contentsOf: url), let encrypted = try? EncryptionService.encrypt(data: data) {
            let encURL = FilePaths.audioDirectory().appendingPathComponent(UUID().uuidString).appendingPathExtension("enc")
            try? encrypted.write(to: encURL)
            audioPath = encURL.path
        }
        let bill = Bill(amount: amount, category: category, timestamp: Date(), note: note, audioPath: audioPath, transcript: transcript, syncStatus: .pending, updatedAt: Date(), isDeleted: false)
        context.insert(bill)
    }

    private func appendWave(_ level: Float) {
        waveform.append(level)
        if waveform.count > 100 { waveform.removeFirst(waveform.count - 100) }
    }

    
}
