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
    var onMarkPaid: (RecurringTransactionsService.DBRecurringTransaction) -> Void = { _ in }

    @State private var currencySymbol: String = "$"

    private let sheetBG = Color(red: 0.11, green: 0.11, blue: 0.13)

    // MARK: - Body

    var body: some View {
        let (dueItems, upcomingItems) = partitionItems(items)

        return VStack(alignment: .leading, spacing: 12) {
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
                        if !dueItems.isEmpty {
                            Section {
                                ForEach(dueItems, id: \.id) { item in
                                    dueRow(item)
                                }
                            } header: {
                                Text("Due payments")
                                    .foregroundColor(textMuted)
                            }
                            .listRowBackground(Color.clear)
                        }

                        Section {
                            if upcomingItems.isEmpty {
                                Text("No upcoming payments.")
                                    .font(.caption)
                                    .foregroundColor(textMuted)
                                    .listRowBackground(Color.clear)
                            } else {
                                ForEach(upcomingItems, id: \.id) { item in
                                    upcomingRow(item)
                                }
                            }
                        } header: {
                            Text("Upcoming")
                                .foregroundColor(textMuted)
                        }
                        .listRowBackground(Color.clear)
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

    // MARK: - Rows

    @ViewBuilder
    private func dueRow(_ item: RecurringTransactionsService.DBRecurringTransaction) -> some View {
        HStack(alignment: .center, spacing: 12) {
            CategoryBadge(category: category(for: item))
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.merchant_name)
                    .foregroundColor(textLight)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let dueLabel = duePillText(for: item) {
                    Text(dueLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(indigo.opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(formatAmount(item.amount))
                    .foregroundColor(textLight)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.trailing)

                Button {
                    onMarkPaid(item)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(Color.green)
                        Text("Mark as paid")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(textLight)
                            .underline()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark \(item.merchant_name) as paid")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect(item) }
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func upcomingRow(_ item: RecurringTransactionsService.DBRecurringTransaction) -> some View {
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

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next payment date: \(formatDate(item.next_date))")
                            .font(.caption)
                            .foregroundColor(textMuted)

                        if isActive(item), let dueLabel = duePillText(for: item) {
                            Text(dueLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(indigo.opacity(0.9))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
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

    // MARK: - Partition logic (UI-only)

    private func partitionItems(_ items: [RecurringTransactionsService.DBRecurringTransaction])
        -> (due: [RecurringTransactionsService.DBRecurringTransaction],
            upcoming: [RecurringTransactionsService.DBRecurringTransaction]) {

        var due: [RecurringTransactionsService.DBRecurringTransaction] = []
        var upcoming: [RecurringTransactionsService.DBRecurringTransaction] = []

        for item in items {
            if isActive(item), isDue(item) {
                due.append(item)
            } else {
                upcoming.append(item)
            }
        }
        return (due, upcoming)
    }

    // MARK: - Due helpers

    private func isActive(_ item: RecurringTransactionsService.DBRecurringTransaction) -> Bool {
        item.status.lowercased() == RecurringTransactionsService.RecurrenceStatus.active.rawValue
    }

    private func isDue(_ item: RecurringTransactionsService.DBRecurringTransaction) -> Bool {
        guard let date = parseLocalDate(item.next_date) else { return false }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let next = cal.startOfDay(for: date)
        return next <= today
    }

    private func duePillText(for item: RecurringTransactionsService.DBRecurringTransaction) -> String? {
        guard let next = parseLocalDate(item.next_date) else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let nd = cal.startOfDay(for: next)

        if nd == today { return "Due today" }
        if nd < today {
            if let days = cal.dateComponents([.day], from: nd, to: today).day {
                return "Overdue \(days)d"
            }
            return "Overdue"
        }
        return nil
    }

    // MARK: - Category

    private func category(for item: RecurringTransactionsService.DBRecurringTransaction) -> ExpenseCategory {
        if let raw = item.category?.lowercased(),
           let cat = ExpenseCategory(rawValue: raw) {
            return cat
        }
        return .other
    }

    // MARK: - Date & formatting

    private func parseLocalDate(_ yyyyMMdd: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: yyyyMMdd)
    }

    private func formatDate(_ yyyyMMdd: String) -> String {
        let inF = DateFormatter()
        inF.calendar = Calendar(identifier: .gregorian)
        inF.locale = Locale(identifier: "en_US_POSIX")
        inF.timeZone = TimeZone.current
        inF.dateFormat = "yyyy-MM-dd"

        let outF = DateFormatter()
        outF.dateFormat = "MMM d"
        let tz = TimeZone.current
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

    // MARK: - Currency

    private func loadCurrencySymbol() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id
            if let code = try await ProfilesService.shared.getUserCurrency(userId: userId),
               let sym = CurrencySymbols.symbols[code] { // <- removed unnecessary try?
                currencySymbol = sym
            } else {
                currencySymbol = "$"
            }
        } catch {
            currencySymbol = "$"
        }
    }
}

