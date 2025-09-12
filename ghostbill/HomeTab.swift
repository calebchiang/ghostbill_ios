//
//  HomeTab.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI
import Supabase

struct DBTransaction: Decodable, Identifiable {
    let id: UUID
    let user_id: UUID
    let amount: Double
    let currency: String
    let date: Date
    let merchant: String?
    let category: String?
    let note: String?
    let created_at: Date
    let updated_at: Date
}

struct HomeTab: View {
    let reloadKey: UUID

    @EnvironmentObject var session: SessionStore
    @State private var transactions: [DBTransaction] = []
    @State private var loading = true

    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Overview(transactions: transactions)

                    HStack {
                        Text("Recent Transactions")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(textLight)
                        Spacer()
                    }
                    .padding(.horizontal)

                    if loading {
                        // 👉 Skeleton that matches TransactionsList’s card layout
                        TransactionsSkeletonList(rowCount: 8)
                            .padding(.horizontal)
                    } else {
                        TransactionsList(transactions: transactions)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 24)
                }
                .padding(.top, 12)
            }
        }
        // Runs on first appear and whenever reloadKey changes
        .task(id: reloadKey) {
            await loadTransactions()
        }
    }

    private func loadTransactions() async {
        loading = true
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id

            let fetched: [DBTransaction] = try await SupabaseManager.shared.client
                .from("transactions")
                .select()
                .eq("user_id", value: userId)
                .order("date", ascending: false)
                .limit(50)
                .execute()
                .value

            self.transactions = fetched
        } catch {
            self.transactions = []
        }
        loading = false
    }
}
