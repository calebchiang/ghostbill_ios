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

    // MARK: - Row models

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

    private struct PlanRow: Decodable, Sendable {
        let monthly_plan: Bool?
        let yearly_plan: Bool?
        let free_plan:   Bool?
    }

    // MARK: - Flags (seen_*)

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
        _ = try await client.from("profiles").update(Patch(seen_home_tour: seen))
            .eq("user_id", value: userId).execute()
    }

    func setSeenRecurringTour(userId: UUID, seen: Bool = true) async throws {
        struct Patch: Encodable { let seen_recurring_tour: Bool }
        _ = try await client.from("profiles").update(Patch(seen_recurring_tour: seen))
            .eq("user_id", value: userId).execute()
    }

    func setSeenSavingsTour(userId: UUID, seen: Bool = true) async throws {
        struct Patch: Encodable { let seen_savings_tour: Bool }
        _ = try await client.from("profiles").update(Patch(seen_savings_tour: seen))
            .eq("user_id", value: userId).execute()
    }

    func setSeenPaywall(userId: UUID, seen: Bool = true) async throws {
        struct Patch: Encodable { let seen_paywall: Bool }
        _ = try await client.from("profiles").update(Patch(seen_paywall: seen))
            .eq("user_id", value: userId).execute()
    }

    // MARK: - Currency

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

    // MARK: - Plan flags (monthly / yearly / free)

    /// Read current plan flags.
    func getPlanStatus(userId: UUID) async throws -> (monthly: Bool, yearly: Bool, free: Bool) {
        let rows: [PlanRow] = try await client
            .from("profiles")
            .select("monthly_plan,yearly_plan,free_plan")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        let r = rows.first
        let monthly = r?.monthly_plan ?? false
        let yearly  = r?.yearly_plan  ?? false
        // If free_plan is missing, derive as not monthly and not yearly
        let free    = r?.free_plan ?? (!monthly && !yearly)
        return (monthly, yearly, free)
    }

    /// Atomic plan update ensuring mutual exclusivity and keeping `free_plan` in sync.
    func setPlans(userId: UUID, monthly: Bool, yearly: Bool) async throws {
        // Enforce mutual exclusivity: if both are true, prefer `yearly`.
        let resolvedYearly  = yearly || (yearly && monthly)
        let resolvedMonthly = monthly && !resolvedYearly
        let free = !(resolvedMonthly || resolvedYearly)

        struct Patch: Encodable {
            let monthly_plan: Bool
            let yearly_plan: Bool
            let free_plan:   Bool
        }

        _ = try await client
            .from("profiles")
            .update(Patch(monthly_plan: resolvedMonthly,
                          yearly_plan: resolvedYearly,
                          free_plan: free))
            .eq("user_id", value: userId)
            .execute()
    }

    /// Convenience: activate monthly, turn off yearly, set free=false.
    func setMonthlyActive(userId: UUID) async throws {
        try await setPlans(userId: userId, monthly: true, yearly: false)
    }

    /// Convenience: activate yearly, turn off monthly, set free=false.
    func setYearlyActive(userId: UUID) async throws {
        try await setPlans(userId: userId, monthly: false, yearly: true)
    }

    /// Convenience: clear to free (no paid plan active).
    func setFree(userId: UUID) async throws {
        try await setPlans(userId: userId, monthly: false, yearly: false)
    }
}

