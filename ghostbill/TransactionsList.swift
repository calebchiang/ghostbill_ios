//
//  TransactionsList.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI

// Bridge DB string -> canonical enum used by UI mapping
extension DBTransaction {
    var categoryEnum: ExpenseCategory {
        guard let raw = category?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              let cat = ExpenseCategory(rawValue: raw) else {
            return .other
        }
        return cat
    }
}

struct TransactionRow: View {
    let transaction: DBTransaction

    var body: some View {
        HStack(spacing: 16) {
            // Uses CategoryBadge from CategoryIcons.swift
            CategoryBadge(category: transaction.categoryEnum)

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant ?? "Unknown")
                    .font(.headline)
                Text(formattedDate(transaction.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            Text(formattedAmount(transaction.amount))
                .font(.headline)
                .foregroundColor(transaction.amount < 0 ? .red : .green)
                .frame(alignment: .trailing)
        }
        .padding(.vertical, 8)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: date)
    }

    private func formattedAmount(_ amount: Double) -> String {
        let sign = amount < 0 ? "-" : "+"
        return "\(sign)\(String(format: "%.2f", abs(amount)))"
    }
}

struct TransactionsList: View {
    let transactions: [DBTransaction]
    var onSelect: (DBTransaction) -> Void = { _ in } // injected from parent

    @State private var page: Int = 1
    private let pageSize = 10

    private let cardBG = Color(red: 0.14, green: 0.14, blue: 0.17)

    var body: some View {
        VStack(spacing: 0) {
            if transactions.isEmpty {
                VStack(spacing: 8) {
                    Text("No transactions recorded yet")
                        .font(.headline)
                    Text("Add your first expense to see it here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(currentPageItems) { tx in
                        // Make the entire row tappable
                        Button {
                            onSelect(tx)
                        } label: {
                            TransactionRow(transaction: tx)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider().opacity(0.08)
                    }
                    pagerFooterRow
                        .padding(.vertical, 10)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(cardBG)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 8)
    }

    private var totalPages: Int {
        max(1, Int(ceil(Double(transactions.count) / Double(pageSize))))
    }

    private var currentPageItems: [DBTransaction] {
        let start = (page - 1) * pageSize
        let end = min(start + pageSize, transactions.count)
        if start < end { return Array(transactions[start..<end]) }
        return []
    }

    private var pagerFooterRow: some View {
        HStack {
            Spacer()
            HStack(spacing: 12) {
                Button {
                    if page > 1 { page -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(page == 1)

                Text("Page \(page) of \(totalPages)")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Button {
                    if page < totalPages { page += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(page == totalPages)
            }
        }
    }
}

