import SwiftUI
import SwiftData

struct VoiceRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = VoiceRecordViewModel()
    enum InputMode: Hashable { case audio, manual }
    @State private var mode: InputMode = .audio
    @FocusState private var amountFocused: Bool
    @FocusState private var noteFocused: Bool
    private var isValidAmount: Bool {
        if let r = vm.amountText.range(of: "[0-9]+(\\.[0-9]{1,2})?", options: .regularExpression) { return Double(vm.amountText[r]) ?? 0 > 0 }
        return false
    }
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
                        Section("消费信息") {
                            HStack(spacing: 8) {
                                Text("¥")
                                TextField("金额", text: $vm.amountText)
                                    .keyboardType(.decimalPad)
                                    .focused($amountFocused)
                                    .onChange(of: vm.amountText) { _, newValue in
                                        if let r = newValue.range(of: "[0-9]+(\\.[0-9]{1,2})?", options: .regularExpression) {
                                            let num = String(newValue[r])
                                            if num != newValue { vm.amountText = num }
                                        } else {
                                            vm.amountText = ""
                                        }
                                    }
                            }
                        }
                        Section("类别") {
                            Picker("类别", selection: $vm.category) {
                                ForEach(Category.allCases, id: \.self) { c in
                                    Text(c.cnName).tag(c)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        Section("备注") {
                            TextField("备注", text: $vm.note)
                                .focused($noteFocused)
                        }
                        Section {
                            HStack {
                                Button("保存") { vm.saveBill(context: modelContext) }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!isValidAmount)
                                Button("清空") {
                                    vm.amountText = ""
                                    vm.category = .other
                                    vm.note = ""
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("语音账单")
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Picker("录入方式", selection: $mode) {
                    Text("音频").tag(InputMode.audio)
                    Text("手动").tag(InputMode.manual)
                }
                .pickerStyle(.segmented)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { amountFocused = false; noteFocused = false }
            }
        }
        .sheet(isPresented: $vm.showConfirm) {
            ConfirmSheetView(vm: vm)
                .presentationDetents([.medium, .large])
        }
    }
}

struct ConfirmSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var vm: VoiceRecordViewModel
    var totalAmount: Double {
        vm.parsedItems.reduce(0) { $0 + (Double($1.amountText) ?? 0) }
    }
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                HStack {
                    Text("已解析 \(vm.parsedItems.count) 笔")
                        .font(.headline)
                    Spacer()
                    Text("总计 ¥\(String(format: "%.2f", totalAmount))")
                        .font(.headline)
                }
                .padding(.horizontal)
                List {
                    ForEach($vm.parsedItems) { $item in
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Text("¥")
                                TextField("金额", text: $item.amountText)
                                    .keyboardType(.decimalPad)
                                    .onChange(of: item.amountText) { _, newValue in
                                        if let r = newValue.range(of: "[0-9]+(\\.[0-9]{1,2})?", options: .regularExpression) {
                                            let num = String(newValue[r])
                                            if num != newValue { item.amountText = num }
                                        } else {
                                            item.amountText = ""
                                        }
                                    }
                            }
                            Picker("类别", selection: $item.category) {
                                ForEach(Category.allCases, id: \.self) { c in
                                    Text(c.cnName).tag(c)
                                }
                            }
                            .pickerStyle(.menu)
                            TextField("备注", text: $item.note)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("确认保存")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { vm.cancelConfirm() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存全部") { vm.saveParsedBills(context: modelContext) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
