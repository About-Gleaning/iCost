import SwiftUI
import SwiftData
import Charts

struct TrendChartView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = ChartsViewModel()
    var body: some View {
        VStack {
            Picker("范围", selection: $vm.range) {
                Text("周").tag(Calendar.Component.weekOfYear)
                Text("月").tag(Calendar.Component.month)
                Text("年").tag(Calendar.Component.year)
            }
            .pickerStyle(.segmented)
            Chart(vm.trend) {
                LineMark(x: .value("日期", $0.date), y: .value("总额", $0.total))
            }
            .frame(height: 240)
            HStack {
                Button("导出 PNG") { ChartExporter.exportPNG(view: AnyView(chartView), fileName: "trend.png") }
                Button("导出 PDF") { ChartExporter.exportPDF(view: AnyView(chartView), fileName: "trend.pdf") }
            }
        }
        .padding()
        .onAppear { vm.load(context: modelContext) }
        .onChange(of: vm.range) { _, _ in vm.load(context: modelContext) }
    }
    private var chartView: some View {
        Chart(vm.trend) { LineMark(x: .value("日期", $0.date), y: .value("总额", $0.total)) }.frame(width: 320, height: 240)
    }
}
