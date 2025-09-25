//
//  TransactionsFilterView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-25.
//

import SwiftUI
import Supabase

struct TransactionsFilterView: View {
    let categories: [ExpenseCategory]
    let initialSelectedCategories: Set<ExpenseCategory>
    let initialSelectedMonths: Set<Date>
    var onApply: (Set<ExpenseCategory>, Set<Date>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<ExpenseCategory>
    @State private var months: [FilterTransactionsService.TxMonth] = []
    @State private var selectedMonths: Set<Date>
    @State private var loadingMonths = false
    @State private var activeTab: Tab = .date

    enum Tab { case date, category }

    init(
        categories: [ExpenseCategory],
        initialSelectedCategories: Set<ExpenseCategory>,
        initialSelectedMonths: Set<Date>,
        onApply: @escaping (Set<ExpenseCategory>, Set<Date>) -> Void
    ) {
        self.categories = categories
        self.initialSelectedCategories = initialSelectedCategories
        self.initialSelectedMonths = initialSelectedMonths
        self.onApply = onApply
        _selected = State(initialValue: initialSelectedCategories)
        _selectedMonths = State(initialValue: initialSelectedMonths)
    }

    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let card = Color(red: 0.14, green: 0.14, blue: 0.17)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Filter transactions by")
                    .font(.headline)
                Spacer()
                Button("Apply") {
                    onApply(selected, selectedMonths)
                    dismiss()
                }
                .font(.headline)
            }
            .padding()
            .background(bg.opacity(0.95))

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Button {
                        activeTab = .date
                        loadMonthsIfNeeded()
                    } label: {
                        Text("Date")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(activeTab == .date ? Color.white.opacity(0.20) : Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        activeTab = .category
                    } label: {
                        Text("Category")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(activeTab == .category ? Color.white.opacity(0.20) : Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)

                Group {
                    if activeTab == .date {
                        dateSection
                    } else {
                        categorySection
                    }
                }
            }
            .padding(.top, 8)
            .background(bg.ignoresSafeArea())
        }
        .background(bg.ignoresSafeArea())
        .task {
            if activeTab == .date {
                loadMonthsIfNeeded()
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    Button {
                        selected.removeAll()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: selected.isEmpty ? "checkmark.circle.fill" : "circle")
                                .imageScale(.small)
                            Text("All")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(categories, id: \.self) { cat in
                        Button {
                            if selected.contains(cat) {
                                selected.remove(cat)
                            } else {
                                selected.insert(cat)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selected.contains(cat) ? "checkmark.circle.fill" : "circle")
                                    .imageScale(.small)
                                Text(cat.title)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Date")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if loadingMonths {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(0..<6, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(card)
                                .frame(height: 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                                .redacted(reason: .placeholder)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            } else if months.isEmpty {
                Text("No months found")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        Button {
                            selectedMonths.removeAll()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selectedMonths.isEmpty ? "checkmark.circle.fill" : "circle")
                                    .imageScale(.small)
                                Text("All")
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        ForEach(months, id: \.id) { m in
                            let monthDate = m.monthStart
                            let isSelected = selectedMonths.contains(monthDate)
                            Button {
                                if isSelected {
                                    selectedMonths.remove(monthDate)
                                } else {
                                    selectedMonths.insert(monthDate)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .imageScale(.small)
                                    Text(shortMonthYear(monthDate))
                                        .font(.subheadline)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.9)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(card)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            loadMonthsIfNeeded()
        }
    }

    private func loadMonthsIfNeeded() {
        guard months.isEmpty, !loadingMonths else { return }
        Task {
            loadingMonths = true
            defer { loadingMonths = false }
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                let userId = session.user.id
                months = try await FilterTransactionsService.shared.getMonthsWithActivity(userId: userId)
            } catch {
                months = []
            }
        }
    }

    private func shortMonthYear(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "LLL yyyy"
        return df.string(from: date)
    }
}

