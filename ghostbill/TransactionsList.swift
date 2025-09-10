//
//  TransactionsList.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI

struct TransactionRow: View {
    let transaction: DBTransaction

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "cart.fill")
                        .foregroundColor(.blue)
                )

            // Merchant + Category
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant ?? "Unknown")
                    .font(.headline)
                Text(transaction.category ?? "Other")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            // Date column (no year, e.g., "September 6")
            Text(formattedDate(transaction.date))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)

            Spacer(minLength: 8)

            // Amount
            Text(formattedAmount(transaction.amount))
                .font(.headline)
                .foregroundColor(transaction.amount < 0 ? .red : .green)
                .frame(alignment: .trailing)
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
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

    var body: some View {
        if transactions.isEmpty {
            VStack(spacing: 8) {
                Text("No transactions recorded yet")
                    .font(.headline)
                Text("Add your first expense to see it here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(transactions) { tx in
                TransactionRow(transaction: tx)
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
    }
}

