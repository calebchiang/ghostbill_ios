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

        // 🔔 Notification columns
        let notifications_enabled: Bool
        let notify_lead_days: Int?
        let notify_time: String?        // e.g., "09:00:00" or "09:00"

        let created_at: Date?
        let updated_at: Date?
    }

    // MARK: - INSERT

    func insertRecurringTransaction(
        userId: UUID,
        merchantName: String,
        amount: Double,
        category: String? = nil,
        frequency: RecurrenceFrequency,
        startDate: Date,
        nextDate: Date? = nil,
        status: RecurrenceStatus = .active,

        // 🔔 Notification params coming from the UI
        notificationsEnabled: Bool = false,
        notifyLeadDays: Int? = nil,
        notifyTime: Date? = nil
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

            // 🔔 New columns
            let notifications_enabled: Bool
            let notify_lead_days: Int?
            let notify_time: String?
        }

        let start = DateOnlyFormatter.shared.string(from: startDate)
        let next  = DateOnlyFormatter.shared.string(from: nextDate ?? startDate)

        let timeString: String? = {
            guard notificationsEnabled, let notifyTime else { return nil }
            return TimeOnlyFormatter.shared.string(from: notifyTime) // "HH:mm"
        }()

        let payload = Payload(
            user_id: userId,
            merchant_name: merchantName,
            amount: amount,
            category: category,
            frequency: frequency,
            start_date: start,
            next_date: next,
            status: status,
            notifications_enabled: notificationsEnabled,
            notify_lead_days: notificationsEnabled ? notifyLeadDays : nil,
            notify_time: timeString
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

    // MARK: - UPDATE

    /// Partially updates a recurring transaction. Only non-nil parameters are sent to the DB.
    func updateRecurringTransaction(
        userId: UUID,
        id: UUID,
        merchantName: String? = nil,
        amount: Double? = nil,
        category: String? = nil,
        frequency: RecurrenceFrequency? = nil,
        startDate: Date? = nil,
        nextDate: Date? = nil,
        status: RecurrenceStatus? = nil,

        // 🔔 Notifications — just persisted; no scheduling logic here
        notificationsEnabled: Bool? = nil,
        notifyLeadDays: Int? = nil,
        notifyTime: Date? = nil
    ) async throws -> DBRecurringTransaction {

        let startString: String? = startDate.map { DateOnlyFormatter.shared.string(from: $0) }
        let nextString:  String? = nextDate.map  { DateOnlyFormatter.shared.string(from: $0) }
        let timeString:  String? = notifyTime.map { TimeOnlyFormatter.shared.string(from: $0) }

        let payload = UpdatePayload(
            merchant_name: merchantName,
            amount: amount,
            category: category,
            frequency: frequency,
            start_date: startString,
            next_date: nextString,
            status: status,
            notifications_enabled: notificationsEnabled,
            notify_lead_days: notifyLeadDays,
            notify_time: timeString
        )

        let updated: DBRecurringTransaction = try await client
            .from("recurring_transactions")
            .update(payload)
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .select("*")
            .single()
            .execute()
            .value

        return updated
    }

    // MARK: - DELETE

    func deleteRecurringTransaction(
        userId: UUID,
        id: UUID
    ) async throws {
        _ = try await client
            .from("recurring_transactions")
            .delete()
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - LIST

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

// MARK: - Encoders

/// Formats only year-month-day for Postgres `date`.
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

/// Formats only hour/minute for Postgres `time`.
private final class TimeOnlyFormatter {
    static let shared: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current   // store local wall-clock time (no tz)
        f.dateFormat = "HH:mm"
        return f
    }()
}

/// A partial update payload that only encodes non-nil keys.
private struct UpdatePayload: Encodable {
    let merchant_name: String?
    let amount: Double?
    let category: String?
    let frequency: RecurringTransactionsService.RecurrenceFrequency?
    let start_date: String?
    let next_date: String?
    let status: RecurringTransactionsService.RecurrenceStatus?

    let notifications_enabled: Bool?
    let notify_lead_days: Int?
    let notify_time: String?

    enum CodingKeys: String, CodingKey {
        case merchant_name, amount, category, frequency, start_date, next_date, status
        case notifications_enabled, notify_lead_days, notify_time
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let merchant_name { try c.encode(merchant_name, forKey: .merchant_name) }
        if let amount { try c.encode(amount, forKey: .amount) }
        if let category { try c.encode(category, forKey: .category) }
        if let frequency { try c.encode(frequency, forKey: .frequency) }
        if let start_date { try c.encode(start_date, forKey: .start_date) }
        if let next_date { try c.encode(next_date, forKey: .next_date) }
        if let status { try c.encode(status, forKey: .status) }

        if let notifications_enabled { try c.encode(notifications_enabled, forKey: .notifications_enabled) }
        if let notify_lead_days { try c.encode(notify_lead_days, forKey: .notify_lead_days) }
        if let notify_time { try c.encode(notify_time, forKey: .notify_time) }
    }
}

