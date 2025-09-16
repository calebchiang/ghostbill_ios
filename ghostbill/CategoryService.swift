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

    // MARK: - Top categories (counts)

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
            .select("category,type,amount")       // select FIRST => FilterBuilder
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

    // MARK: - Spending over time (monthly totals)

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

        guard let startDate = calendar.date(byAdding: .month, value: -monthsBack + 1, to: now.startOfMonth(using: calendar)) else {
            return []
        }

        let rows: [Row] = try await client
            .from("transactions")
            .select("date,type,amount")
            .eq("user_id", value: userId)
            .gte("date", value: startDate)
            .execute()
            .value

        var buckets: [Date: Double] = [:]
        for r in rows {
            if let t = r.type, t.lowercased() == "income" { continue }
            guard let amt = r.amount, amt < 0 else { continue }

            let m = r.date.startOfMonth(using: calendar)
            buckets[m, default: 0] += abs(amt)
        }

        var points: [SpendingPoint] = []
        for offset in (0..<monthsBack).reversed() {
            if let m = calendar.date(byAdding: .month, value: -offset, to: now.startOfMonth(using: calendar)) {
                let total = buckets[m] ?? 0
                points.append(SpendingPoint(monthStart: m, total: total))
            }
        }

        return points
    }

    // MARK: - Category detail helpers (for ExpandedCategoryView)

    /// Fetch all expense transactions for a given category (newest → oldest).
    /// - Filters out income and non-negative rows.
    /// - Optionally bound by [start, end).
    func getTransactionsForCategory(
        userId: UUID,
        category: ExpenseCategory,
        start: Date? = nil,
        end: Date? = nil
    ) async throws -> [DBTransaction] {
        var query = client
            .from("transactions")
            .select() // select FIRST
            .eq("user_id", value: userId)
            .eq("category", value: category.rawValue)
            .neq("type", value: "income")
            .lt("amount", value: 0) // expenses stored as negatives

        if let start { query = query.gte("date", value: start) }
        if let end   { query = query.lt("date", value: end) }

        let rows: [DBTransaction] = try await query
            .order("date", ascending: false)
            .execute()
            .value

        return rows
    }

    /// Sum of spending for a category (absolute value of negative amounts).
    /// - Excludes income rows.
    /// - Optionally bound by [start, end).
    func sumSpendForCategory(
        userId: UUID,
        category: ExpenseCategory,
        start: Date? = nil,
        end: Date? = nil
    ) async throws -> Double {
        struct Row: Decodable { let amount: Double?; let type: String? }

        var query = client
            .from("transactions")
            .select("amount,type")  // select FIRST
            .eq("user_id", value: userId)
            .eq("category", value: category.rawValue)
            .neq("type", value: "income")
            .lt("amount", value: 0)

        if let start { query = query.gte("date", value: start) }
        if let end   { query = query.lt("date", value: end) }

        let rows: [Row] = try await query.execute().value

        return rows.reduce(0) { sum, r in
            guard let amt = r.amount, amt < 0 else { return sum }
            return sum + abs(amt)
        }
    }

    /// Returns month-start dates (newest → oldest) where this category has at least one expense transaction.
    /// - Optionally limited to the last `monthsBack` months window ending at `now`.
    func getMonthsWithActivityForCategory(
        userId: UUID,
        category: ExpenseCategory,
        monthsBack: Int = 24,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> [Date] {
        struct Row: Decodable { let date: Date; let amount: Double?; let type: String? }

        let windowStart = calendar.date(byAdding: .month, value: -monthsBack + 1, to: now.startOfMonth(using: calendar))

        var query = client
            .from("transactions")
            .select("date,amount,type") // select FIRST
            .eq("user_id", value: userId)
            .eq("category", value: category.rawValue)
            .neq("type", value: "income")
            .lt("amount", value: 0)

        if let windowStart {
            query = query.gte("date", value: windowStart)
        }

        let rows: [Row] = try await query.execute().value

        var set: Set<Date> = []
        for r in rows {
            if let t = r.type, t.lowercased() == "income" { continue }
            guard let amt = r.amount, amt < 0 else { continue }
            set.insert(r.date.startOfMonth(using: calendar))
        }

        // Newest → oldest
        return set.sorted(by: { $0 > $1 })
    }
}

// MARK: - Date helpers
private extension Date {
    func startOfMonth(using calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: comps)!
    }
}

