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
    let spending: Double   // absolute outflows
    let savings: Double    // income - spending
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

struct TransactionsService {
    static let shared = TransactionsService()
    private let client = SupabaseManager.shared.client

    // MARK: - Profile

    // Fetch currency from profiles (may be nil)
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

    // MARK: - Insert one transaction

    // Insert a single transaction and return the inserted row
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

    // MARK: - Month helpers

    /// Consistent month range in the given timezone: [start, end)
    private func monthBounds(for monthDate: Date, timezone: TimeZone) throws -> (start: Date, end: Date) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone

        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: monthDate)),
              let monthEnd = cal.date(byAdding: DateComponents(month: 1), to: monthStart) else {
            throw NSError(domain: "TransactionsService", code: -10, userInfo: [NSLocalizedDescriptionKey: "Failed to compute month bounds."])
        }
        return (monthStart, monthEnd)
    }

    // MARK: - Income presence

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

    // MARK: - Month aggregates (client-side)

    /// Sum of all income amounts (positive) in the month (client-side sum).
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

        // Income rows are stored positive by design
        return rows.reduce(0) { $0 + $1.amount }
    }

    /// Sum of monthly spending (absolute outflows, client-side).
    /// Assumes expenses are stored as negative amounts. Excludes income rows.
    func sumSpending(userId: UUID, monthDate: Date, timezone: TimeZone = .current) async throws -> Double {
        let (start, end) = try monthBounds(for: monthDate, timezone: timezone)

        struct Row: Decodable { let amount: Double }
        let rows: [Row] = try await client
            .from("transactions")
            .select("amount,type")
            .eq("user_id", value: userId)
            .neq("type", value: "income")
            .lt("amount", value: 0) // only outflows
            .gte("date", value: start)
            .lt("date", value: end)
            .execute()
            .value

        // amounts are negative -> take absolute
        return rows.reduce(0) { $0 + abs($1.amount) }
    }

    /// Compute income, spending, and savings for the month.
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

    /// One-shot fetch to power the "Total saved this month" card.
    /// If no income has been reported yet, returns hasIncome=false and zeros.
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

    // MARK: - Insert income for a month (single helper)

    /// Inserts a single **income** transaction bucketed to the given month.
    /// - Parameters:
    ///   - userId: current user id
    ///   - amount: positive income amount (will be coerced to positive)
    ///   - monthDate: any date within the month to report (default: today)
    ///   - timezone: timezone used to compute the month's first day (default: device)
    ///   - note: optional note; defaults to "Reported income for {Month Year}"
    /// - Returns: the inserted DBTransaction
    func insertIncomeForMonth(
        userId: UUID,
        amount: Double,
        monthDate: Date = Date(),
        timezone: TimeZone = .current,
        note: String? = nil
    ) async throws -> DBTransaction {
        // Validate amount
        let incomeAmount = abs(amount)
        guard incomeAmount > 0 else {
            throw NSError(domain: "TransactionsService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Income amount must be greater than zero."])
        }

        // Compute first day of the month in the provided timezone
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: monthDate)) else {
            throw NSError(domain: "TransactionsService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to compute month start."])
        }

        // Resolve currency (fallback to USD)
        let currency = (try? await fetchProfileCurrency(userId: userId)) ?? "USD"

        // Build payload explicitly including type = 'income'
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

        // Default note if none provided
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        df.timeZone = timezone
        let monthLabel = df.string(from: monthStart)

        let payload = IncomePayload(
            user_id: userId,
            amount: incomeAmount,               // positive
            currency: currency,
            date: monthStart,                   // bucket to first of month
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
}

