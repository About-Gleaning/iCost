import Foundation
import SwiftData

@MainActor
final class VoiceRecordViewModel: ObservableObject {
    enum Status: Equatable { case idle, recording, processing, done, failed(String) }
    @Published var status: Status = .idle
    @Published var waveform: [Float] = []
    @Published var transcript: String = ""
    @Published var amountText: String = ""
    @Published var category: Category = Category.other
    @Published var note: String = ""
    @Published var showConfirm: Bool = false
    struct EditableBill: Identifiable, Sendable { let id: UUID = UUID(); var amountText: String; var category: Category; var note: String }
    @Published var parsedItems: [EditableBill] = []

    private let recorder = AudioRecorderService()
    private let speech = SpeechService()
    private let parser: any BillParser = QwenBillParser()
    private var recordedURL: URL?
    private var autoSaveAfterStop = false
    private var autoContext: ModelContext?

    func startRecording() {
        status = .recording
        recorder.onMeterUpdate = { [weak self] level in
            DispatchQueue.main.async { self?.appendWave(level) }
        }
        recorder.onFinish = { [weak self] url in
            DispatchQueue.main.async {
                self?.recordedURL = url
                self?.status = .processing
                if let self = self, self.autoSaveAfterStop, let ctx = self.autoContext {
                    Task { await self.analyzeAudioAndSave(context: ctx) }
                    self.autoSaveAfterStop = false
                    self.autoContext = nil
                }
            }
        }
        do { try recorder.start(maxDuration: 60) } catch { status = .failed("录音失败") }
    }

    func stopRecording() { recorder.stop() }

    func analyzeAudioAndSave(context: ModelContext) async {
        guard let url = recordedURL else { return }
        do {
            print("Parser: prepare audio call url=\(url.path)")
            let parsedList = try await parser.parseAudio(url: url)
            parsedItems = parsedList.map { EditableBill(amountText: String(format: "%.2f", $0.amount), category: $0.category, note: $0.note) }
            print("Parser: parsed items count=\(parsedItems.count)")
            status = .done
            showConfirm = true
        } catch {
            status = .failed("解析失败")
            print("Parser: error=\(error.localizedDescription)")
        }
    }

    func prepareAutoSave(context: ModelContext) {
        autoSaveAfterStop = true
        autoContext = context
    }

    

    func analyzeAudioAndAutoSave(context: ModelContext) async {
        guard let url = recordedURL else { return }
        do {
            print("Parser: prepare audio call url=\(url.path)")
            let parsedList = try await parser.parseAudio(url: url)
            parsedItems = parsedList.map { EditableBill(amountText: String(format: "%.2f", $0.amount), category: $0.category, note: $0.note) }
            saveParsedBills(context: context)
        } catch {
            status = .failed("解析失败")
            print("Parser: error=\(error.localizedDescription)")
        }
    }

    

    func saveBill(context: ModelContext) {
        let amount = Double(numericAmount(amountText)) ?? 0
        var audioPath: String? = recordedURL?.path
        if let url = recordedURL, let data = try? Data(contentsOf: url), let encrypted = try? EncryptionService.encrypt(data: data) {
            let encURL = FilePaths.audioDirectory().appendingPathComponent(UUID().uuidString).appendingPathExtension("enc")
            try? encrypted.write(to: encURL)
            audioPath = encURL.path
        }
        let bill = Bill(amount: amount, category: category, timestamp: Date(), note: note, audioPath: audioPath, transcript: transcript, syncStatus: .pending, updatedAt: Date(), isDeleted: false)
        context.insert(bill)
        showConfirm = false
        NotificationCenter.default.post(name: .BillsChanged, object: nil)
        resetInputs()
    }

    func saveParsedBills(context: ModelContext) {
        var audioPath: String? = recordedURL?.path
        if let url = recordedURL, let data = try? Data(contentsOf: url), let encrypted = try? EncryptionService.encrypt(data: data) {
            let encURL = FilePaths.audioDirectory().appendingPathComponent(UUID().uuidString).appendingPathExtension("enc")
            try? encrypted.write(to: encURL)
            audioPath = encURL.path
        }
        for item in parsedItems {
            let amount = Double(numericAmount(item.amountText)) ?? 0
            let bill = Bill(amount: amount, category: item.category, timestamp: Date(), note: item.note, audioPath: audioPath, transcript: transcript, syncStatus: .pending, updatedAt: Date(), isDeleted: false)
            context.insert(bill)
        }
        showConfirm = false
        NotificationCenter.default.post(name: .BillsChanged, object: nil)
        resetInputs()
    }

    private func appendWave(_ level: Float) {
        waveform.append(level)
        if waveform.count > 100 { waveform.removeFirst(waveform.count - 100) }
    }

    private func numericAmount(_ s: String) -> String {
        if let r = s.range(of: "[0-9]+(\\.[0-9]{1,2})?", options: .regularExpression) { return String(s[r]) }
        return "0"
    }

    private func resetInputs() {
        transcript = ""
        amountText = ""
        category = .other
        note = ""
        recordedURL = nil
        waveform.removeAll()
        status = .idle
        parsedItems.removeAll()
    }
    
    func cancelConfirm() {
        showConfirm = false
        status = .idle
    }

    func restartRecording() {
        showConfirm = false
        resetInputs()
        startRecording()
    }
}
