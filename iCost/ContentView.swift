//
//  ContentView.swift
//  iCost
//
//  Created by 刘瑞 on 2025/11/12.
//

import SwiftUI
import SwiftData
import Charts

struct ContentView: View {
    var body: some View {
        TabView {
            BillsListView()
                .tabItem { Label("账单", systemImage: "list.bullet") }
            VoiceRecordView()
                .tabItem { Label("AI", systemImage: "mic") }
            CalendarView()
                .tabItem { Label("日历", systemImage: "calendar") }
        }
    }
}

struct BillsListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var bills: [Bill] = []
    enum TimeRange: Hashable { case day, week, month, all }
    @State private var range: TimeRange = .month
    private func refresh() {
        let descriptor = FetchDescriptor<Bill>(sortBy: [SortDescriptor(\Bill.timestamp, order: .reverse)])
        if let results = try? modelContext.fetch(descriptor) { bills = results }
    }
    private var filteredBills: [Bill] {
        guard range != .all else { return bills }
        let cal = Calendar.current
        let now = Date()
        let start: Date
        switch range {
        case .day:
            start = cal.startOfDay(for: now)
        case .week:
            let comp = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            start = cal.date(from: comp) ?? cal.startOfDay(for: now)
        case .month:
            let comps = cal.dateComponents([.year, .month], from: now)
            start = cal.date(from: comps) ?? cal.startOfDay(for: now)
        case .all:
            start = Date.distantPast
        }
        return bills.filter { $0.timestamp >= start }
    }
    private var groupedByDay: [(date: Date, items: [Bill])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: filteredBills) { cal.startOfDay(for: $0.timestamp) }
        return groups.keys.sorted(by: >).map { d in (d, groups[d]!.sorted { $0.timestamp > $1.timestamp }) }
    }
    private var totalAmount: Double { filteredBills.reduce(0) { $0 + $1.amount } }
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("合计")
                                .font(.headline)
                            Text("¥\(String(format: "%.2f", totalAmount)) · \(filteredBills.count) 笔")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("范围", selection: $range) {
                            Text("当日").tag(TimeRange.day)
                            Text("本周").tag(TimeRange.week)
                            Text("本月").tag(TimeRange.month)
                            Text("全部").tag(TimeRange.all)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 280)
                    }
                    .padding(.vertical, 4)
                }
                ForEach(groupedByDay, id: \.date) { group in
                    Section(header: Text(group.date, format: Date.FormatStyle(date: .complete, time: .omitted))) {
                        ForEach(group.items) { bill in
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(bill.category.cnName)
                                    Spacer()
                                    Text(String(format: "%.2f", bill.amount))
                                }
                                Text(bill.timestamp, format: Date.FormatStyle(date: .omitted, time: .shortened))
                                    .foregroundStyle(.secondary)
                                if let note = bill.note { Text(note).foregroundStyle(.secondary) }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(bill)
                                    NotificationCenter.default.post(name: .BillsChanged, object: nil)
                                    refresh()
                                } label: { Label("删除", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .onAppear { refresh() }
            .onReceive(NotificationCenter.default.publisher(for: .BillsChanged)) { _ in refresh() }
            .navigationTitle("账单")
        }
    }
}

struct ChartsRootView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink("消费趋势", destination: TrendChartView())
                NavigationLink("类别分布", destination: CategoryPieChartView())
            }
            .navigationTitle("图表")
        }
    }
}
