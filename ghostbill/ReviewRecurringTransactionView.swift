//
//  ReviewRecurringTransactionView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-12.
//

import SwiftUI
import Supabase

struct ReviewRecurringTransactionView: View {
    @State private var merchantName: String = ""
    @State private var amountText: String = ""
    @State private var category: ExpenseCategory = .other

    @State private var frequency: RecurringTransactionsService.RecurrenceFrequency = .monthly
    @State private var nextDate: Date = Date()   // holds user's pick (keeps time-of-day unless normalized)

    @State private var isSaving = false
    @State private var errorText: String?

    var onCancel: () -> Void
    var onSaved: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Merchant")) {
                    TextField("e.g. Netflix, Rent", text: $merchantName)
                        .textInputAutocapitalization(.words)
                }

                Section(header: Text("Amount")) {
                    TextField("e.g. 9.99", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                Section(header: Text("Category")) {
                    Picker("Select category", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                Section(header: Text("Schedule")) {
                    Picker("Frequency", selection: $frequency) {
                        Text("Daily").tag(RecurringTransactionsService.RecurrenceFrequency.daily)
                        Text("Weekly").tag(RecurringTransactionsService.RecurrenceFrequency.weekly)
                        Text("Biweekly").tag(RecurringTransactionsService.RecurrenceFrequency.biweekly)
                        Text("Monthly").tag(RecurringTransactionsService.RecurrenceFrequency.monthly)
                        Text("Yearly").tag(RecurringTransactionsService.RecurrenceFrequency.yearly)
                    }

                    DatePicker("Next Payment Date", selection: $nextDate, displayedComponents: .date)
                }

                if let errorText {
                    Section {
                        Text(errorText)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        errorText = nil
        guard !merchantName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorText = "Merchant name is required."
            return
        }
        guard let amt = parseAmount(amountText) else {
            errorText = "Enter a valid amount (e.g., 9.99)."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id

            let startOfDay = Calendar.current.startOfDay(for: nextDate)

            _ = try await RecurringTransactionsService.shared.insertRecurringTransaction(
                userId: userId,
                merchantName: merchantName,
                amount: amt,
                category: category.rawValue,
                frequency: frequency,
                startDate: startOfDay,
                nextDate: startOfDay,
                status: .active
            )

            await MainActor.run { onSaved() }
        } catch {
            await MainActor.run { errorText = error.localizedDescription }
        }
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

private extension ExpenseCategory {
    var displayName: String {
        switch self {
        case .groceries:     return "Groceries"
        case .coffee:        return "Coffee"
        case .dining:        return "Dining"
        case .transport:     return "Transport"
        case .fuel:          return "Fuel"
        case .shopping:      return "Shopping"
        case .utilities:     return "Utilities"
        case .housing:       return "Housing"
        case .entertainment: return "Entertainment"
        case .travel:        return "Travel"
        case .income:        return "Income"
        case .other:         return "Other"
        }
    }
}

