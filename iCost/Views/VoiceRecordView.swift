import SwiftUI
import SwiftData

struct VoiceRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = VoiceRecordViewModel()
    var body: some View {
        VStack(spacing: 16) {
            WaveformView(levels: vm.waveform)
                .frame(height: 120)
            HStack {
                Button(vmButtonTitle) {
                    switch vm.status {
                    case .recording: vm.stopRecording()
                    default: vm.startRecording()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            TextField("识别文本", text: $vm.transcript)
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("金额", text: $vm.amountText)
                    .keyboardType(.decimalPad)
                Picker("类别", selection: $vm.category) {
                    ForEach(Category.allCases) { c in Text(c.rawValue).tag(c) }
                }
            }
            TextField("备注", text: $vm.note)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("保存") { vm.saveBill(context: modelContext) }
                Button("语音直接解析并记录") { Task { await vm.analyzeAudioAndSave(context: modelContext) } }
            }
        }
        .padding()
        .navigationTitle("语音账单")
    }
    private var vmButtonTitle: String {
        switch vm.status { case .recording: return "停止"; default: return "开始录音" }
    }
}

struct WaveformView: View {
    var levels: [Float]
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let barWidth = max(2, width / 60)
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(levels.suffix(60).enumerated()), id: \.offset) { _, l in
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: barWidth, height: CGFloat(max(2, l * 100)))
                }
            }
        }
    }
}
