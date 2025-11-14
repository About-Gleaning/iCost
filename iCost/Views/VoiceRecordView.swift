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
                    let seconds = Int(vm.elapsed)
                    VStack(spacing: 8) {
                        HStack {
                            Label(vm.status == .recording ? "录音中" : (vm.status == .processing ? "正在解析音频…" : "按住开始录音"), systemImage: vm.status == .recording ? "record.circle" : (vm.status == .processing ? "wave.3" : "mic"))
                                .foregroundStyle(vm.status == .recording ? .red : .secondary)
                            Spacer()
                            Text(String(format: "%02d:%02d", seconds/60, seconds%60))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Gauge(value: min(max(Double(vm.currentLevel), 0), 1)) {
                            Text("输入电平")
                        }
                        .gaugeStyle(.linearCapacity)
                    }
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    Spacer(minLength: 80)
                    Circle()
                        .fill(vm.status == .recording ? Color.red : Color.clear)
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(Circle().stroke(vm.status == .recording ? Color.red : Color.accentColor, lineWidth: 2))
                        .shadow(radius: 8)
                        .frame(width: 120, height: 120)
                        .overlay(Image(systemName: "mic.fill").foregroundStyle(vm.status == .recording ? .white : .accentColor))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if vm.status != .recording { vm.prepareAutoSave(context: modelContext); vm.startRecording() }
                                }
                                .onEnded { _ in
                                    vm.stopRecording()
                                }
                        )
                        .padding(.top, 64)
                    if vm.status == .done {
                        Button("重新录制") { vm.restartRecording() }
                            .buttonStyle(.bordered)
                    }
                    if case .failed = vm.status {
                        Button("重新录制") { vm.restartRecording() }
                            .buttonStyle(.bordered)
                    }
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
                            if vm.isIncome {
                                Picker("类别", selection: $vm.incomeCategory) {
                                    ForEach(IncomeCategory.allCases, id: \.self) { c in
                                        Text(c.cnName).tag(c)
                                    }
                                }
                                .pickerStyle(.menu)
                            } else {
                                Picker("类别", selection: $vm.category) {
                                    ForEach(Category.allCases, id: \.self) { c in
                                        Text(c.cnName).tag(c)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        Section("类型") {
                            Picker("类型", selection: $vm.isIncome) {
                                Text("支出").tag(false)
                                Text("收入").tag(true)
                            }
                            .pickerStyle(.segmented)
                        }
                        Section("消费时间") {
                            DatePicker("时间", selection: $vm.consumedAt, displayedComponents: [.date, .hourAndMinute])
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
        .alert("未识别到消费信息", isPresented: $vm.showNoExpenseAlert) {
            Button("重新录制", role: .destructive) { vm.restartRecording() }
            Button("改为手动录入") { mode = .manual }
            Button("忽略", role: .cancel) {}
        } message: {
            Text(vm.noExpenseMessage)
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
                            if item.isIncome {
                                Picker("类别", selection: $item.incomeCategory) {
                                    ForEach(IncomeCategory.allCases, id: \.self) { c in
                                        Text(c.cnName).tag(c)
                                    }
                                }
                                .pickerStyle(.menu)
                            } else {
                                Picker("类别", selection: $item.category) {
                                    ForEach(Category.allCases, id: \.self) { c in
                                        Text(c.cnName).tag(c)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            DatePicker("消费时间", selection: $item.consumedAt, displayedComponents: [.date, .hourAndMinute])
                            Picker("类型", selection: $item.isIncome) {
                                Text("支出").tag(false)
                                Text("收入").tag(true)
                            }
                            .pickerStyle(.segmented)
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
