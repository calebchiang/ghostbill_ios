//
//  TransactionsService.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-11.
//

import Foundation
import Supabase

struct MonthlySavings: Sendable {
    let income: Double
    let spending: Double
    let savings: Double
    let monthStart: Date
    let monthEnd: Date
}

struct SavingsCardData: Sendable {
    let hasIncome: Bool
    let income: Double
    let spending: Double
    let savings: Double
    let currency: String
    let monthStart: Date
    let monthEnd: Date
}

struct SavingsHistory: Sendable {
    struct Point: Sendable {
        let monthStart: Date
        let savings: Double
    }
    let reported: [Point]
    let unreported: [Date]
}

struct TopExpense: Sendable, Identifiable, Decodable {
    let id: UUID
    let merchant: String?
    let date: Date
    let amount: Double
    let currency: String
}

// Top merchants by transaction count (all-time)
struct TopMerchantCount: Sendable, Identifiable, Decodable {
    var id: String { merchant }   // merchant name as stable id
    let merchant: String
    let count: Int
}

struct TransactionsService {
    static let shared = TransactionsService()
    private let client = SupabaseManager.shared.client

    // MARK: - Profile / Base

    func fetchProfileCurrency(userId: UUID) async throws -> String? {
        struct Row: Decodable { let currency: String? }
        let rows: [Row] = try await client
            .from("profiles")
            .select("currency")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.first?.currency
    }

    func insertTransaction(
        userId: UUID,
        amount: Double,
        currency: String,
        date: Date,
        merchant: String?,
        category: ExpenseCategory?,
        note: String?
    ) async throws -> DBTransaction {
        struct Payload: Encodable {
            let user_id: UUID
            let amount: Double
            let currency: String
            let date: Date
            let merchant: String?
            let category: String?
            let note: String?
        }

        let payload = Payload(
            user_id: userId,
            amount: amount,
            currency: currency,
            date: date,
            merchant: merchant,
            category: category?.rawValue,
            note: note
        )

        let inserted: DBTransaction = try await client
            .from("transactions")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        return inserted
    }

    // MARK: - 🔧 Single-transaction helpers (Edit / Remove Prep)

    /// Fetch a single transaction owned by the user.
    func fetchTransaction(userId: UUID, id: UUID) async throws -> DBTransaction? {
        let rows: [DBTransaction] = try await client
            .from("transactions")
            .select()
            .eq("user_id", value: userId)
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Partial update helper. Only non-nil fields are patched.
    /// Returns the updated DBTransaction.
    func updateTransaction(
        userId: UUID,
        id: UUID,
        amount: Double? = nil,
        currency: String? = nil,
        date: Date? = nil,
        merchant: String? = nil,
        category: ExpenseCategory? = nil,
        note: String? = nil
    ) async throws -> DBTransaction {
        struct Patch: Encodable {
            let amount: Double?
            let currency: String?
            let date: Date?
            let merchant: String?
            let category: String?
            let note: String?

            enum CodingKeys: String, CodingKey {
                case amount, currency, date, merchant, category, note
            }
            // Encode ONLY non-nil keys so we don't overwrite with nulls.
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                if let amount { try c.encode(amount, forKey: .amount) }
                if let currency { try c.encode(currency, forKey: .currency) }
                if let date { try c.encode(date, forKey: .date) }
                if let merchant { try c.encode(merchant, forKey: .merchant) }
                if let category { try c.encode(category, forKey: .category) }
                if let note { try c.encode(note, forKey: .note) }
            }
        }

        let patch = Patch(
            amount: amount,
            currency: currency,
            date: date,
            merchant: merchant,
            category: category?.rawValue,
            note: note
        )

        let updated: DBTransaction = try await client
            .from("transactions")
            .update(patch)
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .select()
            .single()
            .execute()
            .value

        return updated
    }

    /// Deletes a transaction owned by the user.
    /// Returns true if no error was thrown.
    @discardableResult
    func deleteTransaction(userId: UUID, id: UUID) async throws -> Bool {
        _ = try await client
            .from("transactions")
            .delete()
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .execute()
        return true
    }

    // MARK: - Date helpers

    private func monthBounds(for monthDate: Date, timezone: TimeZone) throws -> (start: Date, end: Date) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone

        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: monthDate)),
              let monthEnd = cal.date(byAdding: DateComponents(month: 1), to: monthStart) else {
            throw NSError(domain: "TransactionsService", code: -10, userInfo: [NSLocalizedDescriptionKey: "Failed to compute month bounds."])
        }
        return (monthStart, monthEnd)
    }

    // MARK: - Activity / Income flags

    private func hasAnyActivityForMonth(
        userId: UUID,
        monthDate: Date,
        timezone: TimeZone = .current
    ) async throws -> Bool {
        let (start, end) = try monthBounds(for: monthDate, timezone: timezone)

        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await client
            .from("transactions")
            .select("id")
            .eq("user_id", value: userId)
            .gte("date", value: start)
            .lt("date", value: end)
            .limit(1)
            .execute()
            .value

        return !rows.isEmpty
    }

    func hasIncomeForCurrentMonth(userId: UUID, now: Date = Date(), timezone: TimeZone = .current) async throws -> Bool {
        try await hasIncomeForMonth(userId: userId, monthDate: now, timezone: timezone)
    }

    func hasIncomeForMonth(userId: UUID, monthDate: Date, timezone: TimeZone = .current) async throws -> Bool {
        let (start, end) = try monthBounds(for: monthDate, timezone: timezone)

        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await client
            .from("transactions")
            .select("id")
            .eq("user_id", value: userId)
            .eq("type", value: "income")
            .gte("date", value: start)
            .lt("date", value: end)
            .limit(1)
            .execute()
            .value

        return !rows.isEmpty
    }

    // MARK: - Aggregates

    func sumIncome(userId: UUID, monthDate: Date, timezone: TimeZone = .current) async throws -> Double {
        let (start, end) = try monthBounds(for: monthDate, timezone: timezone)

        struct Row: Decodable { let amount: Double }
        let rows: [Row] = try await client
            .from("transactions")
            .select("amount")
            .eq("user_id", value: userId)
            .eq("type", value: "income")
            .gte("date", value: start)
            .lt("date", value: end)
            .execute()
            .value

        return rows.reduce(0) { $0 + $1.amount }
    }

    func sumSpending(userId: UUID, monthDate: Date, timezone: TimeZone = .current) async throws -> Double {
        let (start, end) = try monthBounds(for: monthDate, timezone: timezone)

        struct Row: Decodable { let amount: Double }
        let rows: [Row] = try await client
            .from("transactions")
            .select("amount,type")
            .eq("user_id", value: userId)
            .neq("type", value: "income")
            .lt("amount", value: 0)
            .gte("date", value: start)
            .lt("date", value: end)
            .execute()
            .value

        return rows.reduce(0) { $0 + abs($1.amount) }
    }

    func computeMonthlySavings(userId: UUID, monthDate: Date, timezone: TimeZone = .current) async throws -> MonthlySavings {
        let (start, end) = try monthBounds(for: monthDate, timezone: timezone)
        async let incomeTask = sumIncome(userId: userId, monthDate: monthDate, timezone: timezone)
        async let spendingTask = sumSpending(userId: userId, monthDate: monthDate, timezone: timezone)

        let (income, spending) = try await (incomeTask, spendingTask)
        return MonthlySavings(
            income: income,
            spending: spending,
            savings: income - spending,
            monthStart: start,
            monthEnd: end
        )
    }

    func getSavingsCardData(userId: UUID, monthDate: Date, timezone: TimeZone = .current) async throws -> SavingsCardData {
        let hasIncome = try await hasIncomeForMonth(userId: userId, monthDate: monthDate, timezone: timezone)
        let currency = (try? await fetchProfileCurrency(userId: userId)) ?? "USD"

        if !hasIncome {
            let (start, end) = try monthBounds(for: monthDate, timezone: timezone)
            return SavingsCardData(
                hasIncome: false,
                income: 0,
                spending: 0,
                savings: 0,
                currency: currency,
                monthStart: start,
                monthEnd: end
            )
        }

        let ms = try await computeMonthlySavings(userId: userId, monthDate: monthDate, timezone: timezone)
        return SavingsCardData(
            hasIncome: true,
            income: ms.income,
            spending: ms.spending,
            savings: ms.savings,
            currency: currency,
            monthStart: ms.monthStart,
            monthEnd: ms.monthEnd
        )
    }

    // MARK: - Savings history

    func getSavingsHistory(
        userId: UUID,
        monthsBack: Int = 12,
        now: Date = Date(),
        timezone: TimeZone = .current
    ) async throws -> SavingsHistory {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone

        guard let currentMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) else {
            throw NSError(domain: "TransactionsService", code: -11, userInfo: [NSLocalizedDescriptionKey: "Failed to compute current month start."])
        }
        let monthStarts: [Date] = (0..<monthsBack).compactMap { i in
            cal.date(byAdding: .month, value: -(monthsBack - 1 - i), to: currentMonthStart)
        }

        struct Flags { let hasIncome: Bool; let hasActivity: Bool }
        let flags: [Flags] = try await withThrowingTaskGroup(of: (Int, Flags).self) { group in
            for (idx, m) in monthStarts.enumerated() {
                group.addTask {
                    async let inc = self.hasIncomeForMonth(userId: userId, monthDate: m, timezone: timezone)
                    async let act = self.hasAnyActivityForMonth(userId: userId, monthDate: m, timezone: timezone)
                    let (hasIncome, hasActivity) = try await (inc, act)
                    return (idx, Flags(hasIncome: hasIncome, hasActivity: hasActivity))
                }
            }
            var tmp = Array(repeating: Flags(hasIncome: false, hasActivity: false), count: monthStarts.count)
            for try await (idx, f) in group { tmp[idx] = f }
            return tmp
        }

        let reportedPoints: [SavingsHistory.Point] = try await withThrowingTaskGroup(of: (Int, SavingsHistory.Point).self) { group in
            for (idx, m) in monthStarts.enumerated() where flags[idx].hasIncome {
                group.addTask {
                    async let inc = self.sumIncome(userId: userId, monthDate: m, timezone: timezone)
                    async let exp = self.sumSpending(userId: userId, monthDate: m, timezone: timezone)
                    let (income, spending) = try await (inc, exp)
                    let savings = max(0, income - spending)
                    return (idx, SavingsHistory.Point(monthStart: m, savings: savings))
                }
            }
            var pairs: [(Int, SavingsHistory.Point)] = []
            for try await pair in group { pairs.append(pair) }
            return pairs.sorted { $0.0 < $1.0 }.map { $0.1 }
        }

        let unreported: [Date] = zip(monthStarts, flags)
            .filter { $0.1.hasActivity && !$0.1.hasIncome }
            .map { $0.0 }
            .sorted()

        return SavingsHistory(reported: reportedPoints, unreported: unreported)
    }

    // MARK: - Income insert

    func insertIncomeForMonth(
        userId: UUID,
        amount: Double,
        monthDate: Date = Date(),
        timezone: TimeZone = .current,
        note: String? = nil
    ) async throws -> DBTransaction {
        let incomeAmount = abs(amount)
        guard incomeAmount > 0 else {
            throw NSError(domain: "TransactionsService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Income amount must be greater than zero."])
        }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: monthDate)) else {
            throw NSError(domain: "TransactionsService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to compute month start."])
        }

        let currency = (try? await fetchProfileCurrency(userId: userId)) ?? "USD"

        struct IncomePayload: Encodable {
            let user_id: UUID
            let amount: Double
            let currency: String
            let date: Date
            let merchant: String?
            let category: String?
            let note: String?
            let type: String
        }

        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        df.timeZone = timezone
        let monthLabel = df.string(from: monthStart)

        let payload = IncomePayload(
            user_id: userId,
            amount: incomeAmount,
            currency: currency,
            date: monthStart,
            merchant: "Income",
            category: "income",
            note: note ?? "Reported income for \(monthLabel)",
            type: "income"
        )

        let inserted: DBTransaction = try await client
            .from("transactions")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        return inserted
    }

    // MARK: - Top expenses

    func getTopExpensesForMonth(
        userId: UUID,
        monthDate: Date,
        limit: Int = 10,
        timezone: TimeZone = .current
    ) async throws -> [TopExpense] {
        let (start, end) = try monthBounds(for: monthDate, timezone: timezone)
        return try await getTopExpenses(
            userId: userId,
            start: start,
            end: end,
            limit: limit
        )
    }

    /// All-time top expenses (no date bounds).
    func getTopExpensesAllTime(
        userId: UUID,
        limit: Int = 10
    ) async throws -> [TopExpense] {
        try await getTopExpenses(
            userId: userId,
            start: nil,
            end: nil,
            limit: limit
        )
    }

    /// Generic top expenses over an optional window.
    /// - Note: We fetch a small buffer and sort by absolute amount in Swift
    ///         to ensure correctness when negatives represent spend.
    func getTopExpenses(
        userId: UUID,
        start: Date? = nil,
        end: Date? = nil,
        limit: Int = 10
    ) async throws -> [TopExpense] {
        struct Row: Decodable {
            let id: UUID
            let merchant: String?
            let date: Date
            let amount: Double
            let currency: String
            let type: String?
        }

        var query = client
            .from("transactions")
            .select("id,merchant,date,amount,currency,type")
            .eq("user_id", value: userId)
            .neq("type", value: "income")
            .lt("amount", value: 0)

        if let start { query = query.gte("date", value: start) }
        if let end   { query = query.lt("date", value: end) }

        let rows: [Row] = try await query
            .order("amount", ascending: true)         // most negative first (largest spend)
            .limit(max(limit * 3, limit))             // fetch buffer, then sort by abs()
            .execute()
            .value

        let top = rows
            .sorted { abs($0.amount) > abs($1.amount) }
            .prefix(limit)
            .map {
                TopExpense(
                    id: $0.id,
                    merchant: $0.merchant,
                    date: $0.date,
                    amount: abs($0.amount),
                    currency: $0.currency
                )
            }

        return Array(top)
    }

    // MARK: - Top merchants by count (all-time, client-side aggregate)

    /// Returns the top merchants by number of transactions (all-time), excluding income rows
    /// and excluding empty/null merchant names. Sorted desc by count, limited to `limit`.
    /// Note: This implementation aggregates client-side to support SDKs without `.group(...)`.
    func getTopMerchantsByCountAllTime(
        userId: UUID,
        limit: Int = 10
    ) async throws -> [TopMerchantCount] {
        struct Row: Decodable {
            let merchant: String?
            let type: String?
        }

        // Pull only the columns we need to keep payload light.
        let rows: [Row] = try await client
            .from("transactions")
            .select("merchant,type")
            .eq("user_id", value: userId)
            .neq("type", value: "income")
            .execute()
            .value

        // Case-insensitive counting while preserving a display name.
        var counts: [String: (count: Int, display: String)] = [:]  // key = lowercased merchant
        for r in rows {
            guard let raw = r.merchant?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { continue }
            let key = raw.lowercased()
            if let cur = counts[key] {
                counts[key] = (cur.count + 1, cur.display)
            } else {
                counts[key] = (1, raw)
            }
        }

        let sorted = counts
            .map { TopMerchantCount(merchant: $0.value.display, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(limit)

        return Array(sorted)
    }
}

