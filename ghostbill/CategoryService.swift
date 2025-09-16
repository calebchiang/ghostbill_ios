//
//  CategoryService.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-15.
//

import Foundation
import Supabase

struct TopCategoryCount: Sendable, Identifiable {
    var id: String { category.rawValue }
    let category: ExpenseCategory
    let count: Int
}

struct SpendingPoint: Sendable, Identifiable {
    var id: Date { monthStart }
    let monthStart: Date
    let total: Double
}

struct CategoryService {
    static let shared = CategoryService()
    private let client = SupabaseManager.shared.client

    /// All-time top expense categories by number of transactions.
    /// - Includes only expenses (amount < 0) and excludes rows marked as `type == "income"`.
    /// - Returns most → least frequent categories.
    func getTopExpenseCategoriesByCountAllTime(
        userId: UUID,
        limit: Int? = nil
    ) async throws -> [TopCategoryCount] {
        struct Row: Decodable {
            let category: String?
            let type: String?
            let amount: Double?
        }

        let rows: [Row] = try await client
            .from("transactions")
            .select("category,type,amount")
            .eq("user_id", value: userId)
            .execute()
            .value

        var counts: [ExpenseCategory: Int] = [:]

        for r in rows {
            if let t = r.type, t.lowercased() == "income" { continue }
            if let amt = r.amount, amt >= 0 { continue }

            let key = (r.category ?? "").lowercased()
            let cat = ExpenseCategory(rawValue: key) ?? .other
            counts[cat, default: 0] += 1
        }

        var result = counts
            .map { TopCategoryCount(category: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        if let limit, limit > 0, result.count > limit {
            result = Array(result.prefix(limit))
        }

        return result
    }

    /// Spending totals by month (last `monthsBack` months, default 12).
    /// - Only includes expense transactions (amount < 0, not income).
    /// - Fills missing months with zero totals.
    func getSpendingOverTime(
        userId: UUID,
        monthsBack: Int = 12,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> [SpendingPoint] {
        struct Row: Decodable {
            let date: Date
            let type: String?
            let amount: Double?
        }

        // Determine the earliest month to include
        guard let startDate = calendar.date(byAdding: .month, value: -monthsBack + 1, to: now.startOfMonth(using: calendar)) else {
            return []
        }

        // Fetch transactions in window
        let rows: [Row] = try await client
            .from("transactions")
            .select("date,type,amount")
            .eq("user_id", value: userId)
            .gte("date", value: ISO8601DateFormatter().string(from: startDate))
            .execute()
            .value

        // Bucket by month
        var buckets: [Date: Double] = [:]
        for r in rows {
            if let t = r.type, t.lowercased() == "income" { continue }
            guard let amt = r.amount, amt < 0 else { continue }

            let m = r.date.startOfMonth(using: calendar)
            buckets[m, default: 0] += abs(amt)
        }

        // Build full list of months (ensure gaps are zeroed)
        var points: [SpendingPoint] = []
        for offset in (0..<monthsBack).reversed() {
            if let m = calendar.date(byAdding: .month, value: -offset, to: now.startOfMonth(using: calendar)) {
                let total = buckets[m] ?? 0
                points.append(SpendingPoint(monthStart: m, total: total))
            }
        }

        return points
    }
}

// MARK: - Date helpers
private extension Date {
    func startOfMonth(using calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: comps)!
    }
}

