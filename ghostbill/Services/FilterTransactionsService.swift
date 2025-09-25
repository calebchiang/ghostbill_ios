//
//  FilterTransactionsService.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-25.
//

import Foundation
import Supabase

struct FilterTransactionsService {
    static let shared = FilterTransactionsService()
    private let client = SupabaseManager.shared.client

    struct TxMonth: Sendable, Identifiable, Hashable {
        let monthStart: Date
        let count: Int
        var id: TimeInterval { monthStart.timeIntervalSince1970 }
    }

    func getMonthsWithActivity(
        userId: UUID,
        timezone: TimeZone = .current
    ) async throws -> [TxMonth] {
        struct Row: Decodable { let date: Date }

        let rows: [Row] = try await client
            .from("transactions")
            .select("date")
            .eq("user_id", value: userId)
            .order("date", ascending: false)
            .execute()
            .value

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone

        var counts: [Date: Int] = [:]
        for r in rows {
            if let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: r.date)) {
                counts[monthStart, default: 0] += 1
            }
        }

        return counts
            .map { TxMonth(monthStart: $0.key, count: $0.value) }
            .sorted { $0.monthStart > $1.monthStart }
    }
}
