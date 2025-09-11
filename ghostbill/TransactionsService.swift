//
//  TransactionsService.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-11.
//

import Foundation
import Supabase

struct TransactionsService {
    static let shared = TransactionsService()
    private let client = SupabaseManager.shared.client

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

        // NOTE: no 'values:' label
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

