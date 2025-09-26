//
//  FeedbackService.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-25.
//

import Foundation
import Supabase

struct DBFeedback: Decodable, Identifiable, Hashable {
    let id: UUID
    let user_id: UUID
    let message: String
    let email: String?
    let created_at: Date
}

struct FeedbackService {
    static let shared = FeedbackService()
    private let client = SupabaseManager.shared.client

    private struct NewFeedback: Encodable {
        let user_id: UUID
        let message: String
        let email: String?
    }

    func insertFeedback(userId: UUID, message: String, email: String?) async throws -> DBFeedback {
        let payload = NewFeedback(
            user_id: userId,
            message: message,
            email: (email?.isEmpty == true) ? nil : email
        )

        let rows: [DBFeedback] = try await client
            .from("feedback")
            .insert(payload, returning: .representation)
            .execute()
            .value

        if let first = rows.first { return first }
        throw NSError(domain: "FeedbackService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Insert failed"])
    }
}
