import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = CalendarViewModel()
    var body: some View {
        VStack {
            HStack {
                Button(action: { vm.moveMonth(by: -1, context: modelContext) }) { Image(systemName: "chevron.left") }
                Spacer()
                Text(vm.currentMonth, format: .dateTime.year().month())
                Spacer()
                Button(action: { vm.moveMonth(by: 1, context: modelContext) }) { Image(systemName: "chevron.right") }
            }
            .padding(.horizontal)
            GridView(days: vm.days) { date in
                BillsDayDetailView(date: date)
            }
        }
        .onAppear { vm.load(context: modelContext) }
        .navigationTitle("月历")
    }
}

struct GridView: View {
    let days: [DayItem]
    let onSelect: (Date) -> Void
    var body: some View {
        let cal = Calendar.current
        let first = cal.date(from: cal.dateComponents([.year, .month], from: days.first?.date ?? Date())) ?? Date()
        let startWeekday = cal.component(.weekday, from: first)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<startWeekday-1, id: \.self) { _ in Color.clear.frame(height: 44) }
            ForEach(days) { day in
                VStack {
                    Text(Calendar.current.component(.day, from: day.date).description)
                    Text(String(format: "%.0f", day.total)).font(.caption)
                }
                .frame(height: 44)
                .onTapGesture { onSelect(day.date) }
            }
        }
        .padding()
    }
}

struct BillsDayDetailView: View {
    let date: Date
    var body: some View {
        Text(date, format: .dateTime.year().month().day())
    }
}
