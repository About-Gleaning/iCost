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
                    if vm.status == .processing {
                        ProgressView("正在解析音频…")
                    }
                    Circle()
                        .fill(vm.status == .recording ? Color.red : Color.accentColor)
                        .frame(width: 120, height: 120)
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
                    Text("按住开始录音，松开结束并确认")
                        .foregroundStyle(.secondary)
                } else {
                    Form {
                        Section {
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
                        Section {
                            Picker("类别", selection: $vm.category) {
                                ForEach(Category.allCases, id: \.self) { c in
                                    Text(c.cnName).tag(c)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        Section {
                            TextField("备注", text: $vm.note)
                        }
                        Section {
                            Button("保存") { vm.saveBill(context: modelContext) }
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("语音账单")
            if vm.showConfirm { confirmOverlay }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Picker("录入方式", selection: $mode) {
                    Text("音频").tag(InputMode.audio)
                    Text("手动").tag(InputMode.manual)
                }
                .pickerStyle(.segmented)
            }
        }
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
                Picker("类别", selection: $vm.category) {
                    ForEach(Category.allCases, id: \.self) { c in
                        Text(c.cnName).tag(c)
                    }
                }
                .pickerStyle(.menu)
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
