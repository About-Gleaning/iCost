import Foundation
import SwiftData

struct TrendPoint: Identifiable { let id = UUID(); let date: Date; let total: Double }
struct CategorySlice: Identifiable { let id = UUID(); let category: Category; let total: Double }

@MainActor
final class ChartsViewModel: ObservableObject {
    @Published var range: Calendar.Component = .month
    @Published var trend: [TrendPoint] = []
    @Published var slices: [CategorySlice] = []

    func load(context: ModelContext) {
        let now = Date()
        var from: Date
        switch range {
        case .weekOfYear: from = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        case .year: from = Calendar.current.date(byAdding: .year, value: -1, to: now)!
        default: from = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        }
        let descriptor = FetchDescriptor<Bill>(predicate: #Predicate { $0.timestamp >= from && $0.timestamp <= now })
        if let results = try? context.fetch(descriptor) {
            let cal = Calendar.current
            let groupedByDay = Dictionary(grouping: results) { cal.startOfDay(for: $0.timestamp) }
            trend = groupedByDay.keys.sorted().map { d in TrendPoint(date: d, total: groupedByDay[d]?.reduce(0) { $0 + $1.amount } ?? 0) }
            let groupedByCategory = Dictionary(grouping: results) { $0.category }
            slices = groupedByCategory.map { CategorySlice(category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
        }
    }
}
