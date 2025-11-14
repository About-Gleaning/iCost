import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate: Date = Date()
    @State private var bills: [Bill] = []
    @State private var total: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            DatePicker("选择日期", selection: $selectedDate, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .onChange(of: selectedDate) { _, _ in fetch() }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedDate, format: .dateTime.year().month().day())
                        .font(.headline)
                    Text("\(bills.count) 笔 · ¥\(String(format: "%.2f", total))")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)

            List {
                if bills.isEmpty {
                    VStack(alignment: .center) {
                        Text("当日暂无记录")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    }
                } else {
                    Section(header: Text("当日账单")) {
                        ForEach(bills) { bill in
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(bill.category.cnName)
                                    Spacer()
                                    Text(String(format: "%.2f", bill.amount))
                                }
                                if let note = bill.note { Text(note).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .onAppear { fetch() }
        .navigationTitle("日历")
        .environment(\.locale, Locale(identifier: "zh_CN"))
    }

    private func fetch() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: selectedDate)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let descriptor = FetchDescriptor<Bill>(predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end }, sortBy: [SortDescriptor(\Bill.timestamp, order: .reverse)])
        if let results = try? modelContext.fetch(descriptor) {
            bills = results
            total = results.reduce(0) { $0 + $1.amount }
        }
    }
}
