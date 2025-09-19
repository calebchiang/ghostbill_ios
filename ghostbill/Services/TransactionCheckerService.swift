//
//  TransactionCheckerService.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-18.
//

import Foundation
import Supabase

struct TransactionCheckerService {
    static let shared = TransactionCheckerService()
    private let client = SupabaseManager.shared.client
    
    // MARK: - Monthly transaction count
    
    /// Returns how many transactions the user has created in the current month.
    func getMonthlyTransactionCount(
        userId: UUID,
        monthDate: Date = Date(),
        timezone: TimeZone = .current
    ) async throws -> Int {
        let (start, end) = try monthBounds(for: monthDate, timezone: timezone)
        
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await client
            .from("transactions")
            .select("id")
            .eq("user_id", value: userId)
            .gte("created_at", value: start)
            .lt("created_at", value: end)
            .execute()
            .value
        
        return rows.count
    }
    
    // MARK: - Remaining free transactions
    
    /// Returns how many free transactions remain this month.
    /// - Parameters:
    ///   - userId: The user to check.
    ///   - maxFree: Maximum free transactions allowed (default = 5).
    /// - Returns: Remaining transactions (never less than 0).
    func remainingFreeTransactions(
        userId: UUID,
        monthDate: Date = Date(),
        timezone: TimeZone = .current,
        maxFree: Int = 5
    ) async throws -> Int {
        let count = try await getMonthlyTransactionCount(
            userId: userId,
            monthDate: monthDate,
            timezone: timezone
        )
        return max(0, maxFree - count)
    }
    
    // MARK: - Helpers
    
    private func monthBounds(
        for monthDate: Date,
        timezone: TimeZone
    ) throws -> (start: Date, end: Date) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone
        
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: monthDate)),
              let monthEnd = cal.date(byAdding: DateComponents(month: 1), to: monthStart) else {
            throw NSError(
                domain: "TransactionCheckerService",
                code: -10,
                userInfo: [NSLocalizedDescriptionKey: "Failed to compute month bounds."]
            )
        }
        return (monthStart, monthEnd)
    }
}
