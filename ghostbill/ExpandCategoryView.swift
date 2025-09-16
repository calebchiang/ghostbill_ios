//
//  ExpandCategoryView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-16.
//

import SwiftUI
import Supabase

struct ExpandedCategoryView: View {
    let category: ExpenseCategory

    // Palette
    private let bg        = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let cardBG    = Color(red: 0.14, green: 0.14, blue: 0.17)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let stroke    = Color.white.opacity(0.06)

    // Data
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var totalAllTime: Double = 0
    @State private var currencyCode: String = "USD"

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Header card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            CategoryBadge(category: category)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.title)
                                    .font(.headline)
                                    .foregroundColor(textLight)
                                Text("All-time spend")
                                    .font(.caption)
                                    .foregroundColor(textMuted)
                            }
                            Spacer()
                        }

                        if isLoading {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 36)
                                .redacted(reason: .placeholder)
                        } else if let errorText {
                            Text(errorText)
                                .foregroundColor(.red)
                                .font(.footnote)
                        } else {
                            Text(formatAmount(totalAllTime, code: currencyCode))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .accessibilityLabel("All time \(category.title) spending \(formatAmount(totalAllTime, code: currencyCode))")
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20).fill(cardBG)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20).stroke(stroke, lineWidth: 1)
                    )

                    // Placeholder for future: filters + transaction list
                    // (For now, spec asks only for all-time total.)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAllTime() }
    }

    // MARK: - Data

    private func loadAllTime() async {
        isLoading = true
        errorText = nil

        do {
            // Get user id
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id

            // Currency (fallback to USD)
            let profileCurrency = try await TransactionsService.shared.fetchProfileCurrency(userId: userId) ?? "USD"

            // All-time spend for this category
            let total = try await CategoryService.shared.sumSpendForCategory(
                userId: userId,
                category: category,
                start: nil,
                end: nil
            )

            await MainActor.run {
                self.currencyCode = profileCurrency
                self.totalAllTime = total
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorText = (error as NSError).localizedDescription
            }
        }
    }

    // MARK: - Formatting

    private func formatAmount(_ value: Double, code: String) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = code
        // Keep the same UX you used elsewhere (US-style $ symbol)
        nf.currencySymbol = "$"
        nf.maximumFractionDigits = 2
        nf.minimumFractionDigits = 2
        return nf.string(from: NSNumber(value: value)) ?? "$\(String(format: "%.2f", value))"
    }
}
