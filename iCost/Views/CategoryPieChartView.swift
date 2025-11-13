import SwiftUI
import SwiftData
import Charts

struct CategoryPieChartView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = ChartsViewModel()
    var body: some View {
        VStack {
            Chart(vm.slices) {
                SectorMark(angle: .value("总额", $0.total))
                    .foregroundStyle(by: .value("类别", $0.category.rawValue))
            }
            .frame(height: 260)
            HStack {
                Button("导出 PNG") { ChartExporter.exportPNG(view: AnyView(chartView), fileName: "pie.png") }
                Button("导出 PDF") { ChartExporter.exportPDF(view: AnyView(chartView), fileName: "pie.pdf") }
            }
        }
        .padding()
        .onAppear { vm.load(context: modelContext) }
    }
    private var chartView: some View {
        Chart(vm.slices) { SectorMark(angle: .value("总额", $0.total)).foregroundStyle(by: .value("类别", $0.category.rawValue)) }.frame(width: 320, height: 240)
    }
}
