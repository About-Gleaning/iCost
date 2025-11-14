import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate: Date = Date()
    @State private var bills: [Bill] = []
    @State private var total: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            DatePicker("选择日期", selection: $selectedDate, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .onChange(of: selectedDate) { _, _ in fetch() }

            HStack {
                Text(selectedDate, format: .dateTime.year().month().day())
                Spacer()
                Text(String(format: "当日总额：¥%.2f", total))
            }
            .padding(.horizontal)

            List {
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
