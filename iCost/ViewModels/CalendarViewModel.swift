import Foundation
import SwiftData

struct DayItem: Identifiable {
    let id = UUID()
    let date: Date
    let total: Double
}

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var currentMonth: Date = Date()
    @Published var days: [DayItem] = []

    func load(context: ModelContext) {
        let range = monthRange(for: currentMonth)
        let startDate = range.start
        let endDate = range.end
        
        let descriptor = FetchDescriptor<Bill>(
            predicate: #Predicate { bill in
                bill.timestamp >= startDate && bill.timestamp <= endDate
            }
        )
        
        if let results = try? context.fetch(descriptor) {
            let calendar = Calendar.current
            let grouped = Dictionary(grouping: results) { calendar.startOfDay(for: $0.timestamp) }
            days = grouped.keys.sorted().map { date in
                let total = grouped[date]?.reduce(0) { $0 + $1.amount } ?? 0
                return DayItem(date: date, total: total)
            }
        }
    }

    func moveMonth(by delta: Int, context: ModelContext) {
        if let next = Calendar.current.date(byAdding: .month, value: delta, to: currentMonth) { currentMonth = next; load(context: context) }
    }

    private func monthRange(for date: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: date))!
        let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start.addingTimeInterval(60*60*24))!
        return (start, end)
    }
}
