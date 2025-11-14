//
//  Item.swift
//  iCost
//
//  Created by 刘瑞 on 2025/11/12.
//

import Foundation
import SwiftData

enum Category: String, Codable, CaseIterable, Identifiable {
    case food
    case transport
    case entertainment
    case shopping
    case daily
    case medical
    case education
    case other
    var id: String { rawValue }
    var cnName: String {
        switch self {
        case .food: return "餐饮"
        case .transport: return "交通"
        case .entertainment: return "娱乐"
        case .shopping: return "购物"
        case .daily: return "日用"
        case .medical: return "医疗"
        case .education: return "教育"
        case .other: return "其他"
        }
    }
}

enum SyncStatus: String, Codable {
    case pending
    case synced
    case failed
}

@Model
final class Bill {
    var id: UUID = UUID()
    var amount: Double = 0
    var category: Category = Category.other
    var timestamp: Date = Date()
    var note: String?
    var audioPath: String?
    var transcript: String?
    var syncStatus: SyncStatus = SyncStatus.pending
    var updatedAt: Date = Date()
    var isDeleted: Bool = false

    init(id: UUID = UUID(), amount: Double, category: Category, timestamp: Date = Date(), note: String? = nil, audioPath: String? = nil, transcript: String? = nil, syncStatus: SyncStatus = .pending, updatedAt: Date = Date(), isDeleted: Bool = false) {
        self.id = id
        self.amount = amount
        self.category = category
        self.timestamp = timestamp
        self.note = note
        self.audioPath = audioPath
        self.transcript = transcript
        self.syncStatus = syncStatus
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
}
