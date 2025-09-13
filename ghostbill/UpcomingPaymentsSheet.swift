//
//  UpcomingPaymentsSheet.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-11.
//

import SwiftUI

struct UpcomingPaymentsSheet: View {
    let textLight: Color
    let textMuted: Color
    let indigo: Color
    let items: [RecurringTransactionsService.DBRecurringTransaction]
    let showContent: Bool

    private let sheetBG = Color(red: 0.26, green: 0.30, blue: 0.62)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming payments")
                .font(.headline)
                .foregroundColor(textLight)

            if showContent {
                if items.isEmpty {
                    // Empty state
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
                    // List of upcoming payments
                    List {
                        ForEach(items, id: \.id) { item in
                            HStack(alignment: .center, spacing: 12) {
                                // Leading icon
                                Circle()
                                    .fill(indigo.opacity(0.20))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Image(systemName: "repeat")
                                            .foregroundColor(indigo)
                                    )

                                // Left column: merchant + next payment date
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

                                // Right column: amount, trailing aligned
                                Text(formatAmount(item.amount))
                                    .foregroundColor(textLight)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .multilineTextAlignment(.trailing)
                                    .frame(alignment: .trailing)
                            }
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
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f.string(from: NSNumber(value: amount)) ?? String(format: "$%.2f", amount)
    }
}

