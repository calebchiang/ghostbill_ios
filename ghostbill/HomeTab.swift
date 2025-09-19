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
    @State private var showingAddSheet = false
    @State private var showingProfile = false
    @State private var showingFeedback = false
    @State private var showingPaywall = false

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
                        HStack(spacing: 12) {
                            Text("Welcome")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(textLight)
                            Spacer()
                            HStack(spacing: 12) {
                                Button { showingFeedback = true } label: {
                                    Image(systemName: "questionmark.circle")
                                        .font(.title2)
                                        .foregroundColor(textLight)
                                }
                                .accessibilityLabel("Open feedback")

                                Button { showingProfile = true } label: {
                                    Image(systemName: "person.crop.circle")
                                        .font(.title2)
                                        .foregroundColor(textLight)
                                }
                                .accessibilityLabel("Open profile")
                            }
                        }
                        .padding(.horizontal)

                        Overview(transactions: transactions)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        HStack {
                            Text("Recent Transactions")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(textLight)
                            Spacer()

                            Button { showingAddSheet = true } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(textLight)
                            }
                            .accessibilityLabel("Add transaction")

                            Spacer().frame(width: 14)

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
                                onSelect: { tx in navPath.append(tx) }
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
        .sheet(isPresented: $showingFeedback) {
            FeedbackView()
        }
        .sheet(isPresented: $showingProfile) {
            UserProfileView()
                .environmentObject(session)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTransactionView(
                onSave: { merchant, amountString, pickedDate, type, category, notes in
                    Task {
                        guard let amountString, let parsed = parseAmount(amountString) else {
                            print("❌ Save error: invalid amount '\(amountString ?? "nil")'")
                            return
                        }
                        let amountToStore = (type == .income) ? abs(parsed) : -abs(parsed)

                        do {
                            let session = try await SupabaseManager.shared.client.auth.session
                            let userId = session.user.id
                            let currency = (try? await TransactionsService.shared.fetchProfileCurrency(userId: userId)) ?? "USD"
                            let dateToStore = pickedDate ?? Date()
                            let typeString = (type == .income) ? "income" : "expense"

                            _ = try await TransactionsService.shared.insertTransaction(
                                userId: userId,
                                amount: amountToStore,
                                currency: currency,
                                date: dateToStore,
                                merchant: (merchant?.isEmpty == true) ? nil : merchant,
                                category: category,
                                note: (notes?.isEmpty == true) ? nil : notes,
                                type: typeString
                            )

                            await MainActor.run { showingAddSheet = false }
                            await loadTransactions()
                        } catch {
                            print("❌ Insert error:", error.localizedDescription)
                        }
                    }
                },
                onCancel: { showingAddSheet = false }
            )
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallView {
                Task {
                    do {
                        let session = try await SupabaseManager.shared.client.auth.session
                        let userId = session.user.id
                        try await ProfilesService.shared.setSeenPaywall(userId: userId, seen: true)
                    } catch {
                        print("⚠️ Failed to persist seen_paywall: \(error.localizedDescription)")
                    }
                    await MainActor.run { showingPaywall = false }
                }
            }
        }
        .task(id: reloadKey) {
            await loadTransactions()
        }
        .task {
            await checkPaywall()
        }
    }

    private func checkPaywall() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id
            let seen = try await ProfilesService.shared.hasSeenPaywall(userId: userId)
            await MainActor.run { showingPaywall = !seen }
        } catch {
            await MainActor.run { showingPaywall = false }
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

    private func currentMonthTitle() -> String {
        let df = DateFormatter()
        df.dateFormat = "LLLL"
        return df.string(from: Date())
    }

    private func parseAmount(_ raw: String) -> Double? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let isParenNegative = s.contains("(") && s.contains(")")
        s = s.replacingOccurrences(of: "$", with: "")
             .replacingOccurrences(of: ",", with: "")
             .replacingOccurrences(of: "(", with: "")
             .replacingOccurrences(of: ")", with: "")
             .replacingOccurrences(of: " ", with: "")
        guard let v = Double(s) else { return nil }
        return isParenNegative ? -v : v
    }
}

