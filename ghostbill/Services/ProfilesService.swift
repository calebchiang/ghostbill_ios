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

    // Internal model for just the four flags
    private struct FlagsRow: Decodable, Sendable {
        let seen_home_tour: Bool
        let seen_recurring_tour: Bool
        let seen_savings_tour: Bool
        let seen_analytics_tour: Bool
    }

    // Fetch the flags row once
    private func fetchFlags(userId: UUID) async throws -> FlagsRow? {
        let rows: [FlagsRow] = try await client
            .from("profiles")
            .select("seen_home_tour,seen_recurring_tour,seen_savings_tour,seen_analytics_tour")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    // MARK: - Public checkers (per-tab)

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

    // MARK: - Setters

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
}

