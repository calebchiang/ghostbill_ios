//
//  UpcomingPaymentsSheet.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-11.
//

import SwiftUI
import Supabase

struct UpcomingPaymentsSheet: View {
    let textLight: Color
    let textMuted: Color
    let indigo: Color
    let items: [RecurringTransactionsService.DBRecurringTransaction]
    let showContent: Bool
    var onSelect: (RecurringTransactionsService.DBRecurringTransaction) -> Void = { _ in }

    @State private var currencySymbol: String = "$"

    private let sheetBG = Color(red: 0.11, green: 0.11, blue: 0.13)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming payments")
                .font(.headline)
                .foregroundColor(textLight)

            if showContent {
                if items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title2)
                            .foregroundColor(textMuted.opacity(0.9))
                        Text("No payments added yet")
                            .foregroundColor(textLight)
                            .font(.subheadline)
                        Text("Tap the + button above to add your first recurring payment.")
                            .foregroundColor(textMuted)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    List {
                        ForEach(items, id: \.id) { item in
                            Button {
                                onSelect(item)
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    CategoryBadge(category: category(for: item))
                                        .frame(width: 36, height: 36)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.merchant_name)
                                            .foregroundColor(textLight)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)

                                        Text("Next payment date: \(formatDate(item.next_date))")
                                            .font(.caption)
                                            .foregroundColor(textMuted)
                                    }

                                    Spacer(minLength: 8)

                                    Text(formatAmount(item.amount))
                                        .foregroundColor(textLight)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .multilineTextAlignment(.trailing)
                                        .frame(alignment: .trailing)
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .transition(.identity)
                    .animation(nil, value: showContent)
                }
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding()
        .background(sheetBG)
        .task {
            await loadCurrencySymbol()
        }
    }

    private func category(for item: RecurringTransactionsService.DBRecurringTransaction) -> ExpenseCategory {
        if let raw = item.category?.lowercased(),
           let cat = ExpenseCategory(rawValue: raw) {
            return cat
        }
        return .other
    }

    private func formatDate(_ yyyyMMdd: String) -> String {
        let inF = DateFormatter()
        inF.calendar = Calendar(identifier: .gregorian)
        inF.locale = Locale(identifier: "en_US_POSIX")
        let tz = TimeZone.current
        inF.timeZone = tz
        inF.dateFormat = "yyyy-MM-dd"

        let outF = DateFormatter()
        outF.dateFormat = "MMM d"
        outF.locale = Locale.current
        outF.timeZone = tz

        if let d = inF.date(from: yyyyMMdd) {
            return outF.string(from: d)
        }
        return yyyyMMdd
    }

    private func formatAmount(_ amount: Double) -> String {
        "\(currencySymbol)\(String(format: "%.2f", amount))"
    }

    private func loadCurrencySymbol() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id
            if let code = try await ProfilesService.shared.getUserCurrency(userId: userId),
               let sym = CurrencySymbols.symbols[code] {
                currencySymbol = sym
            } else {
                currencySymbol = "$"
            }
        } catch {
            currencySymbol = "$"
        }
    }
}
