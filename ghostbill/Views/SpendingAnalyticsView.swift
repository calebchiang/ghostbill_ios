//
//  SpendingAnalyticsView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-13.
//

import SwiftUI
import Supabase
import UIKit

struct SpendingAnalyticsView: View {
    private let cardBG      = Color(red: 0.14, green: 0.14, blue: 0.17)
    private let textLight   = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted   = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let stroke      = Color.white.opacity(0.06)
    private let divider     = Color.white.opacity(0.08)
    private let rankIndigo  = Color(red: 0.58, green: 0.55, blue: 1.00)

    @State private var topExpenses: [TopExpense] = []
    @State private var topMerchants: [TopMerchantCount] = []
    @State private var isLoading = false
    @State private var errorText: String?

    @State private var showAllExpenses = false
    @State private var showAllMerchants = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Card(
                    title: "Top Expensive Purchases",
                    isExpanded: $showAllExpenses
                ) {
                    if let errorText {
                        Text(errorText)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    } else if isLoading && topExpenses.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(0..<5, id: \.self) { i in
                                RowSkeleton()
                                if i < 4 { Divider().background(divider) }
                            }
                        }
                        .padding(.top, 2)
                    } else if topExpenses.isEmpty {
                        Text("No expenses found.")
                            .font(.subheadline)
                            .foregroundColor(textMuted)
                            .padding(.top, 2)
                    } else {
                        let visible = showAllExpenses ? topExpenses.prefix(10) : topExpenses.prefix(5)

                        VStack(spacing: 0) {
                            ForEach(Array(visible.enumerated()), id: \.element.id) { (idx, item) in
                                let rank = idx + 1
                                let merchant = (item.merchant?.isEmpty == false) ? item.merchant! : "Unknown"
                                let amount = formatAmount(item.amount, code: item.currency)
                                let date = Self.shortDate(item.date)

                                HStack(spacing: 12) {
                                    Text("\(rank).")
                                        .font(.callout.weight(.semibold))
                                        .foregroundColor(rankIndigo)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(merchant)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(textLight)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.9)

                                        Text(date)
                                            .font(.caption)
                                            .foregroundColor(textMuted)
                                    }

                                    Spacer(minLength: 8)

                                    Text(amount)
                                        .font(.title3.weight(.semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .frame(alignment: .trailing)
                                }
                                .padding(.horizontal, 2)
                                .padding(.vertical, 10)

                                if rank < visible.count {
                                    Divider().background(divider)
                                }
                            }
                        }
                        .padding(.top, 2)
                        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showAllExpenses)
                    }
                }

                Card(
                    title: "Top merchants by # of transactions",
                    isExpanded: $showAllMerchants
                ) {
                    if let errorText {
                        Text(errorText)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    } else if isLoading && topMerchants.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(0..<5, id: \.self) { i in
                                RowSkeleton()
                                if i < 4 { Divider().background(divider) }
                            }
                        }
                        .padding(.top, 2)
                    } else if topMerchants.isEmpty {
                        Text("No merchant activity found.")
                            .font(.subheadline)
                            .foregroundColor(textMuted)
                            .padding(.top, 2)
                    } else {
                        let visible = showAllMerchants ? topMerchants.prefix(10) : topMerchants.prefix(5)

                        VStack(spacing: 0) {
                            ForEach(Array(visible.enumerated()), id: \.element.id) { (idx, item) in
                                let rank = idx + 1

                                HStack(spacing: 12) {
                                    Text("\(rank).")
                                        .font(.callout.weight(.semibold))
                                        .foregroundColor(rankIndigo)

                                    Text(item.merchant)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(textLight)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.9)

                                    Spacer(minLength: 8)

                                    Text("\(item.count)")
                                        .font(.title3.weight(.semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .frame(alignment: .trailing)
                                        .accessibilityLabel("\(item.count) transactions")
                                }
                                .padding(.horizontal, 2)
                                .padding(.vertical, 10)

                                if rank < visible.count {
                                    Divider().background(divider)
                                }
                            }
                        }
                        .padding(.top, 2)
                        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showAllMerchants)
                    }
                }
            }
            .padding(.vertical, 10)
            .task { await loadData() }
        }
    }

    private func loadData() async {
        isLoading = true
        errorText = nil
        do {
            let session = try? await SupabaseManager.shared.client.auth.session
            guard let uid = session?.user.id else {
                isLoading = false
                errorText = "Not signed in."
                return
            }

            async let expensesTask = TransactionsService.shared.getTopExpensesAllTime(
                userId: uid,
                limit: 10
            )
            async let merchantsTask = TransactionsService.shared.getTopMerchantsByCountAllTime(
                userId: uid,
                limit: 10
            )

            let (items, merchants) = try await (expensesTask, merchantsTask)
            topExpenses = items
            topMerchants = merchants
            isLoading = false
        } catch {
            topExpenses = []
            topMerchants = []
            isLoading = false
            errorText = (error as NSError).localizedDescription
        }
    }

    private func formatAmount(_ value: Double, code: String) -> String {
        let symbol = CurrencySymbols.symbols[code] ?? "$"
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.maximumFractionDigits = 2
        nf.minimumFractionDigits = 2
        nf.currencyCode = code
        nf.currencySymbol = symbol
        return nf.string(from: NSNumber(value: value)) ?? "\(symbol)\(String(format: "%.2f", value))"
    }

    private static func shortDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }

    @ViewBuilder
    private func Card<Content: View>(title: String, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(textLight)
                Spacer()
            }

            content()

            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        isExpanded.wrappedValue.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .rotationEffect(isExpanded.wrappedValue ? .degrees(180) : .degrees(0))
                        .foregroundColor(textMuted)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.06), in: Capsule())
                        .overlay(
                            Capsule().stroke(.white.opacity(0.08), lineWidth: 1)
                        )
                        .accessibilityLabel(isExpanded.wrappedValue ? "Collapse" : "Expand")
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBG)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(stroke, lineWidth: 1)
        )
    }
}

private struct RowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.10))
                .frame(width: 18, height: 14)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 140, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 60, height: 12)
            }

            Spacer(minLength: 8)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.06))
                .frame(width: 84, height: 18)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 10)
        .redacted(reason: .placeholder)
    }
}

