//
//  ProfilesService.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-17.
//

import Foundation
import Supabase

struct ProfilesService {
    static let shared = ProfilesService()
    let client = SupabaseManager.shared.client

    private struct FlagsRow: Decodable, Sendable {
        let seen_home_tour: Bool
        let seen_recurring_tour: Bool
        let seen_savings_tour: Bool
        let seen_analytics_tour: Bool
        let seen_paywall: Bool
    }

    private struct CurrencyRow: Decodable, Sendable {
        let currency: String?
    }
    
    private struct FreePlanRow: Decodable, Sendable {
        let free_plan: Bool
    }

    private func fetchFlags(userId: UUID) async throws -> FlagsRow? {
        let rows: [FlagsRow] = try await client
            .from("profiles")
            .select("seen_home_tour,seen_recurring_tour,seen_savings_tour,seen_analytics_tour,seen_paywall")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func hasSeenHomeTour(userId: UUID) async throws -> Bool {
        try await fetchFlags(userId: userId)?.seen_home_tour ?? false
    }

    func hasSeenRecurringTour(userId: UUID) async throws -> Bool {
        try await fetchFlags(userId: userId)?.seen_recurring_tour ?? false
    }

    func hasSeenSavingsTour(userId: UUID) async throws -> Bool {
        try await fetchFlags(userId: userId)?.seen_savings_tour ?? false
    }

    func hasSeenAnalyticsTour(userId: UUID) async throws -> Bool {
        try await fetchFlags(userId: userId)?.seen_analytics_tour ?? false
    }

    func hasSeenPaywall(userId: UUID) async throws -> Bool {
        try await fetchFlags(userId: userId)?.seen_paywall ?? false
    }

    func setSeenHomeTour(userId: UUID, seen: Bool = true) async throws {
        struct Patch: Encodable { let seen_home_tour: Bool }
        _ = try await client
            .from("profiles")
            .update(Patch(seen_home_tour: seen))
            .eq("user_id", value: userId)
            .execute()
    }

    func setSeenRecurringTour(userId: UUID, seen: Bool = true) async throws {
        struct Patch: Encodable { let seen_recurring_tour: Bool }
        _ = try await client
            .from("profiles")
            .update(Patch(seen_recurring_tour: seen))
            .eq("user_id", value: userId)
            .execute()
    }

    func setSeenSavingsTour(userId: UUID, seen: Bool = true) async throws {
        struct Patch: Encodable { let seen_savings_tour: Bool }
        _ = try await client
            .from("profiles")
            .update(Patch(seen_savings_tour: seen))
            .eq("user_id", value: userId)
            .execute()
    }

    func setSeenPaywall(userId: UUID, seen: Bool = true) async throws {
        struct Patch: Encodable { let seen_paywall: Bool }
        _ = try await client
            .from("profiles")
            .update(Patch(seen_paywall: seen))
            .eq("user_id", value: userId)
            .execute()
    }

    func getUserCurrency(userId: UUID) async throws -> String? {
        let rows: [CurrencyRow] = try await client
            .from("profiles")
            .select("currency")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.first?.currency
    }
    
    // MARK: - Free plan check
    
    func isFreeUser(userId: UUID) async throws -> Bool {
        let rows: [FreePlanRow] = try await client
            .from("profiles")
            .select("free_plan")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.first?.free_plan ?? true
    }
}

