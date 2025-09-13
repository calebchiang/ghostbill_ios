//
//  RecurringTransactionsService.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-12.
//

import Foundation
import Supabase

struct RecurringTransactionsService {
    static let shared = RecurringTransactionsService()
    private let client = SupabaseManager.shared.client

    enum RecurrenceFrequency: String, Encodable {
        case daily, weekly, biweekly, monthly, yearly
    }

    enum RecurrenceStatus: String, Encodable {
        case active, paused, canceled
    }

    struct DBRecurringTransaction: Decodable, Identifiable {
        let id: UUID
        let user_id: UUID
        let merchant_name: String
        let amount: Double
        let category: String?
        let frequency: String
        let start_date: String
        let next_date: String
        let status: String
        let created_at: Date?
        let updated_at: Date?
    }

    // INSERT
    func insertRecurringTransaction(
        userId: UUID,
        merchantName: String,
        amount: Double,
        category: String? = nil,
        frequency: RecurrenceFrequency,
        startDate: Date,
        nextDate: Date? = nil,
        status: RecurrenceStatus = .active
    ) async throws -> DBRecurringTransaction {

        struct Payload: Encodable {
            let user_id: UUID
            let merchant_name: String
            let amount: Double
            let category: String?
            let frequency: RecurringTransactionsService.RecurrenceFrequency
            let start_date: String
            let next_date: String
            let status: RecurringTransactionsService.RecurrenceStatus
        }

        let start = DateOnlyFormatter.shared.string(from: startDate)
        let next  = DateOnlyFormatter.shared.string(from: nextDate ?? startDate)

        let payload = Payload(
            user_id: userId,
            merchant_name: merchantName,
            amount: amount,
            category: category,
            frequency: frequency,
            start_date: start,
            next_date: next,
            status: status
        )

        let inserted: DBRecurringTransaction = try await client
            .from("recurring_transactions")
            .insert(payload)
            .select("*")
            .single()
            .execute()
            .value

        return inserted
    }

    func listRecurringTransactions(userId: UUID) async throws -> [DBRecurringTransaction] {
        let rows: [DBRecurringTransaction] = try await client
            .from("recurring_transactions")
            .select("*")
            .eq("user_id", value: userId)
            .order("next_date", ascending: true)
            .execute()
            .value
        return rows
    }

    func listDueRecurringTransactions(userId: UUID, asOf: Date = Date()) async throws -> [DBRecurringTransaction] {
        let cutoff = DateOnlyFormatter.shared.string(from: asOf)
        let rows: [DBRecurringTransaction] = try await client
            .from("recurring_transactions")
            .select("*")
            .eq("user_id", value: userId)
            .eq("status", value: RecurrenceStatus.active.rawValue)
            .lte("next_date", value: cutoff)
            .order("next_date", ascending: true)
            .execute()
            .value
        return rows
    }
}

private final class DateOnlyFormatter {
    static let shared: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

