//
//  HomeTab.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI
import Supabase

struct DBTransaction: Decodable, Identifiable, Hashable {
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
    @State private var selectedCategory: ExpenseCategory? = nil

    @State private var navPath: [DBTransaction] = []

    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)

    private let categories: [ExpenseCategory] = [
        .groceries, .coffee, .dining, .transport, .fuel, .shopping,
        .utilities, .housing, .entertainment, .travel, .income, .other
    ]

    private var visibleTransactions: [DBTransaction] {
        guard let cat = selectedCategory else { return transactions }
        return transactions.filter { $0.categoryEnum == cat }
    }

    var body: some View {
        NavigationStack(path: $navPath) {
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
                            Menu {
                                Button("All") { selectedCategory = nil }
                                Divider()
                                ForEach(categories, id: \.self) { cat in
                                    Button(cat.title) { selectedCategory = cat }
                                }
                                if selectedCategory != nil {
                                    Divider()
                                    Button("Clear filter", role: .destructive) { selectedCategory = nil }
                                }
                            } label: {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.title3)
                                    .foregroundColor(textLight)
                            }
                        }
                        .padding(.horizontal)

                        if loading {
                            TransactionsSkeletonList(rowCount: 8)
                                .padding(.horizontal)
                        } else {
                            TransactionsList(
                                transactions: visibleTransactions,
                                onSelect: { tx in
                                    navPath.append(tx)
                                }
                            )
                            .id(selectedCategory?.title ?? "all")
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationDestination(for: DBTransaction.self) { tx in
                TransactionView(
                    transaction: tx,
                    onUpdated: { updated in
                        if let idx = transactions.firstIndex(where: { $0.id == updated.id }) {
                            transactions[idx] = updated
                        } else {
                            transactions.append(updated)
                        }
                        transactions.sort { $0.date > $1.date }
                    },
                    onDeleted: { id in
                        transactions.removeAll { $0.id == id }
                    }
                )
                .navigationBarTitleDisplayMode(.inline)
            }
        }
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
                .limit(100)
                .execute()
                .value

            self.transactions = fetched
        } catch {
            self.transactions = []
        }
        loading = false
    }
}

