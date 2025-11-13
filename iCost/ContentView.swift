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
                .tabItem { Label("语音", systemImage: "mic") }
            CalendarView()
                .tabItem { Label("日历", systemImage: "calendar") }
            ChartsRootView()
                .tabItem { Label("图表", systemImage: "chart.pie") }
        }
    }
}

struct BillsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var bills: [Bill]
    init() { _bills = Query(sort: [SortDescriptor(\Bill.timestamp, order: .reverse)]) }
    var body: some View {
        NavigationView {
            List {
                ForEach(bills) { bill in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(bill.category.rawValue)
                            Spacer()
                            Text(String(format: "%.2f", bill.amount))
                        }
                        Text(bill.timestamp, format: Date.FormatStyle(date: .numeric, time: .shortened))
                            .foregroundStyle(.secondary)
                        if let note = bill.note { Text(note).foregroundStyle(.secondary) }
                    }
                }
                .onDelete { indexes in
                    for i in indexes { modelContext.delete(bills[i]) }
                }
            }
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
