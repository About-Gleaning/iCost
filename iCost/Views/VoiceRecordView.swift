import SwiftUI
import SwiftData

struct VoiceRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = VoiceRecordViewModel()
    enum InputMode: Hashable { case audio, manual }
    @State private var mode: InputMode = .audio
    var body: some View {
        ZStack {
        VStack(spacing: 16) {
            if mode == .audio {
                WaveformView(levels: vm.waveform)
                    .frame(height: 120)
                Circle()
                    .fill(vm.status == .recording ? Color.red : Color.accentColor)
                    .frame(width: 96, height: 96)
                    .overlay(Image(systemName: "mic.fill").foregroundStyle(.white))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if vm.status != .recording { vm.prepareAutoSave(context: modelContext); vm.startRecording() }
                            }
                            .onEnded { _ in
                                vm.stopRecording()
                            }
                    )
            } else {
                HStack {
                    TextField("金额", text: $vm.amountText)
                        .keyboardType(.decimalPad)
                        .onChange(of: vm.amountText) { _, newValue in
                            if let r = newValue.range(of: "[0-9]+(\\.[0-9]{1,2})?", options: .regularExpression) {
                                let num = String(newValue[r])
                                if num != newValue { vm.amountText = num }
                            } else {
                                vm.amountText = ""
                            }
                        }
                }
                CategoryGrid(selected: $vm.category)
                TextField("备注", text: $vm.note)
                    .textFieldStyle(.roundedBorder)
                Button("保存") { vm.saveBill(context: modelContext) }
            }
            Picker("录入方式", selection: $mode) {
                Text("音频").tag(InputMode.audio)
                Text("手动").tag(InputMode.manual)
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .navigationTitle("语音账单")
        if vm.showConfirm { confirmOverlay }
        }
    }
    private var vmButtonTitle: String {
        switch vm.status { case .recording: return "停止"; default: return "开始录音" }
    }
}

extension VoiceRecordView {
    private var confirmOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("请确认解析结果").font(.headline)
                TextField("金额", text: $vm.amountText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .onChange(of: vm.amountText) { _, newValue in
                        if let r = newValue.range(of: "[0-9]+(\\.[0-9]{1,2})?", options: .regularExpression) {
                            let num = String(newValue[r])
                            if num != newValue { vm.amountText = num }
                        } else {
                            vm.amountText = ""
                        }
                    }
                CategoryGrid(selected: $vm.category)
                TextField("备注", text: $vm.note)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("确认保存") { vm.saveBill(context: modelContext) }
                        .buttonStyle(.borderedProminent)
                    Button("取消") { vm.cancelConfirm() }
                }
            }
            .padding()
            .background(.thinMaterial)
            .cornerRadius(12)
            .shadow(radius: 10)
            .frame(maxWidth: 360)
        }
        .transition(.opacity)
        .animation(.easeInOut, value: vm.showConfirm)
    }
}

struct CategoryGrid: View {
    @Binding var selected: Category
    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Category.allCases) { c in
                let isSel = c == selected
                Text(c.cnName)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(isSel ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSel ? Color.accentColor : Color.secondary.opacity(0.4)))
                    .cornerRadius(8)
                    .onTapGesture { selected = c }
            }
        }
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
