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
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "cart.fill")
                        .foregroundColor(.blue)
                )

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
    @State private var page: Int = 1
    @State private var showPager: Bool = false
    private let pageSize = 10

    // match HomeTab background
    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)

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
            List {
                ForEach(currentPageItems) { tx in
                    TransactionRow(transaction: tx)
                        .onAppear {
                            if tx.id == currentPageItems.last?.id {
                                showPager = true
                            }
                        }
                }

                if showPager {
                    pagerFooterRow
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(bg) // full-width row background
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
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
                    if page > 1 {
                        page -= 1
                        showPager = false
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(page == 1)

                Text("Page \(page) of \(totalPages)")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Button {
                    if page < totalPages {
                        page += 1
                        showPager = false
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(page == totalPages)
            }
            .padding(.trailing, 16) // keep right-side clear of the scanner button
        }
    }
}

