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
    @State private var overviewTransactions: [DBTransaction] = []
    @State private var loading = true
    @State private var selectedCategories: Set<ExpenseCategory> = []
    @State private var selectedMonths: Set<Date> = []

    @State private var navPath: [DBTransaction] = []
    @State private var showingAddSheet = false
    @State private var showingProfile = false
    @State private var showingPaywall = false
    @State private var showingFilters = false
    @State private var showingExport = false

    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    @State private var showStatusAlert = false
    @State private var statusAlertTitle = ""
    @State private var statusAlertMessage = ""

    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    private let categories: [ExpenseCategory] = [
        .groceries, .coffee, .dining, .transport, .fuel, .shopping,
        .utilities, .housing, .entertainment, .travel, .income, .other
    ]

    private var visibleTransactions: [DBTransaction] {
        if selectedCategories.isEmpty { return transactions }
        return transactions.filter { selectedCategories.contains($0.categoryEnum) }
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
                                Button { showingProfile = true } label: {
                                    Image(systemName: "person.crop.circle")
                                        .font(.title2)
                                        .foregroundColor(textLight)
                                }
                                .accessibilityLabel("Open profile")
                            }
                        }
                        .padding(.horizontal)

                        Overview(
                            transactions: overviewTransactions,
                            onStatusTap: { payload in
                                statusAlertTitle = payload.title
                                statusAlertMessage = payload.message
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.95)) {
                                    showStatusAlert = true
                                }
                            }
                        )
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

                            Button { showingFilters = true } label: {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.title3)
                                    .foregroundColor(textLight)
                            }
                            .accessibilityLabel("Open filters")

                            Spacer().frame(width: 14)

                            Button { showingExport = true } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title3)
                                    .foregroundColor(textLight)
                            }
                            .accessibilityLabel("Open export")
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
                            .id(listIdentity)
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.top, 12)
                }

                if showStatusAlert {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.95)) {
                                showStatusAlert = false
                            }
                        }
                        .zIndex(100)

                    VStack(spacing: 14) {
                        Text(statusAlertTitle)
                            .font(.headline)
                            .foregroundColor(textLight)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(statusAlertMessage)
                            .foregroundColor(textMuted)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button(action: {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.95)) {
                                showStatusAlert = false
                            }
                        }) {
                            Text("Close")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(indigo)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .padding(.top, 6)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(red: 0.13, green: 0.13, blue: 0.16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.45), radius: 20)
                    )
                    .frame(maxWidth: 360)
                    .padding(.horizontal, 24)
                    .zIndex(101)
                    .transition(.scale.combined(with: .opacity))
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
                        Task { await loadOverviewTransactionsCurrentMonth() }
                    },
                    onDeleted: { id in
                        transactions.removeAll { $0.id == id }
                        Task { await loadOverviewTransactionsCurrentMonth() }
                    }
                )
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showingProfile) {
            UserProfileView()
                .environmentObject(session)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTransactionView(
                onSave: { merchant, amountString, pickedDate, type, category, notes in
                    Task {
                        guard let amountString, let parsed = parseAmount(amountString) else { return }
                        let amountToStore = (type == .income) ? abs(parsed) : -abs(parsed)
                        do {
                            let session = try await SupabaseManager.shared.client.auth.session
                            let userId = session.user.id
                            let currency = (try? await TransactionsService.shared.fetchProfileCurrency(userId: userId)) ?? "USD"
                            let dateToStore = pickedDate ?? Date()
                            let typeString = (type == .income) ? "income" : "expense"

                            let isFree = try await ProfilesService.shared.isFreeUser(userId: userId)
                            if isFree {
                                let remaining = try await TransactionCheckerService.shared.remainingFreeTransactions(userId: userId)
                                if remaining <= 0 {
                                    await MainActor.run {
                                        showingAddSheet = false
                                        showToast(message: "Free plan limit reached. Upgrade to add more.", isError: true)
                                    }
                                    return
                                }
                            }

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
                            await loadOverviewTransactionsCurrentMonth()
                            await loadTransactionsForFilters()
                        } catch {
                            await MainActor.run {
                                showingAddSheet = false
                                showToast(message: "Failed to save transaction.", isError: true)
                            }
                        }
                    }
                },
                onCancel: { showingAddSheet = false }
            )
        }
        .sheet(isPresented: $showingFilters) {
            TransactionsFilterView(
                categories: categories,
                initialSelectedCategories: selectedCategories,
                initialSelectedMonths: selectedMonths,
                onApply: { newCategories, newMonths in
                    selectedCategories = newCategories
                    selectedMonths = newMonths
                    showingFilters = false
                    Task { await loadTransactionsForFilters() }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingExport) {
            ExportTransactionsView(onSuccess: { message in
                showToast(message: message, isError: false)
            })
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
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
            await loadOverviewTransactionsCurrentMonth()
            await loadTransactions()
        }
        .task {
            await checkPaywall()
        }
        .overlay(alignment: .top) {
            if showToast {
                HStack(spacing: 10) {
                    Image(systemName: toastIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .imageScale(.large)
                    Text(toastMessage)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(toastIsError ? Color.yellow.opacity(0.9) : Color.green.opacity(0.9))
                )
                .padding(.top, 40)
                .padding(.horizontal, 24)
                .transition(.move(edge: .top).combined(with: .opacity))
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 4)
                .ignoresSafeArea(.keyboard)
            }
        }
    }

    private var listIdentity: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM"
        let monthsKey = selectedMonths.map { df.string(from: $0) }.sorted().joined(separator: "|")
        let catsKey = selectedCategories.map(\.title).sorted().joined(separator: "|")
        return monthsKey + "§" + catsKey
    }

    private func showToast(message: String, isError: Bool) {
        toastMessage = message
        toastIsError = isError
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.easeOut(duration: 0.25)) { showToast = false }
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

    private func loadOverviewTransactionsCurrentMonth() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id

            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = .current
            guard let start = cal.date(from: cal.dateComponents([.year, .month], from: Date())),
                  let end = cal.date(byAdding: .month, value: 1, to: start) else {
                self.overviewTransactions = []
                return
            }

            let fetched: [DBTransaction] = try await SupabaseManager.shared.client
                .from("transactions")
                .select()
                .eq("user_id", value: userId)
                .gte("date", value: start)
                .lt("date", value: end)
                .order("date", ascending: false)
                .execute()
                .value

            self.overviewTransactions = fetched
        } catch {
            self.overviewTransactions = []
        }
    }

    private func loadTransactionsForFilters() async {
        loading = true
        defer { loading = false }
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id

            if selectedMonths.isEmpty {
                let fetched: [DBTransaction] = try await SupabaseManager.shared.client
                    .from("transactions")
                    .select()
                    .eq("user_id", value: userId)
                    .order("date", ascending: false)
                    .limit(100)
                    .execute()
                    .value
                self.transactions = fetched
            } else {
                let fetched = try await TransactionsService.shared.fetchTransactions(
                    userId: userId,
                    months: Array(selectedMonths),
                    categories: selectedCategories
                )
                self.transactions = fetched
            }
        } catch {
            self.transactions = []
        }
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

