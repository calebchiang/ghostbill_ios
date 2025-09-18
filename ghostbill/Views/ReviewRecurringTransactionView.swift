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
    @State private var nextDate: Date = Date()

    @State private var notifyEnabled: Bool = false
    @State private var leadDays: Int = 3
    @State private var notifyTime: Date = {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 9; comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }()

    @State private var isSaving = false
    @State private var errorText: String?

    var onCancel: () -> Void
    var onSaved: () -> Void

    // MARK: - Computed reminder date & validation

    private var computedReminderDate: Date? {
        guard notifyEnabled else { return nil }
        let cal = Calendar.current
        let nextStart = cal.startOfDay(for: nextDate)
        guard let notifyDay = cal.date(byAdding: .day, value: -leadDays, to: nextStart) else { return nil }
        let hm = cal.dateComponents([.hour, .minute], from: notifyTime)
        var comps = cal.dateComponents([.year, .month, .day], from: notifyDay)
        comps.hour = hm.hour
        comps.minute = hm.minute
        return cal.date(from: comps)
    }

    private var reminderInPast: Bool {
        guard let fire = computedReminderDate else { return false }
        return fire <= Date()
    }

    var body: some View {
        NavigationView {
            Form {
                // MARK: Merchant
                Section(header: Text("Merchant")) {
                    TextField("e.g. Netflix, Rent", text: $merchantName)
                        .textInputAutocapitalization(.words)
                }

                // MARK: Amount
                Section(header: Text("Amount")) {
                    TextField("e.g. 9.99", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                // MARK: Category
                Section(header: Text("Category")) {
                    Picker("Select category", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                // MARK: Schedule
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

                // MARK: Notifications (permission requested on toggle)
                Section(header: Text("Notifications")) {
                    Toggle(isOn: $notifyEnabled.animation(.easeInOut(duration: 0.15))) {
                        Text("Enable reminder before next payment")
                    }
                    .onChange(of: notifyEnabled) { isOn in
                        guard isOn else { return }
                        Task {
                            let allowed = await RecurringNotificationsHelper.shared.requestAuthorizationIfNeeded()
                            if !allowed {
                                await MainActor.run {
                                    notifyEnabled = false
                                    errorText = "Notifications are disabled. Enable them in Settings > Notifications > Ghostbill."
                                }
                            }
                        }
                    }

                    if notifyEnabled {
                        Picker("Remind me", selection: $leadDays) {
                            ForEach(1...14, id: \.self) { d in
                                Text(d == 1 ? "1 day before" : "\(d) days before").tag(d)
                            }
                        }

                        DatePicker("Reminder time", selection: $notifyTime, displayedComponents: .hourAndMinute)

                        // Subtle helper text indicating when it will fire (or why it's invalid)
                        if let fire = computedReminderDate {
                            HStack(spacing: 8) {
                                Image(systemName: reminderInPast ? "exclamationmark.triangle.fill" : "bell")
                                Text(reminderInPast
                                     ? "Reminder time is in the past."
                                     : "Will notify \(formatFriendlyDateTime(fire)).")
                            }
                            .font(.footnote)
                            .foregroundColor(reminderInPast ? .orange : .secondary)
                            .padding(.top, 2)
                        }
                    }
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
                    .disabled(isSaving || (notifyEnabled && reminderInPast))
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
        if notifyEnabled && reminderInPast {
            // Extra guard in case button enabling state is bypassed
            errorText = "Reminder time is in the past. Adjust lead days or time."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id

            let startOfDay = Calendar.current.startOfDay(for: nextDate)

            // Insert in DB
            let inserted = try await RecurringTransactionsService.shared.insertRecurringTransaction(
                userId: userId,
                merchantName: merchantName,
                amount: amt,
                category: category.rawValue,
                frequency: frequency,
                startDate: startOfDay,
                nextDate: startOfDay,
                status: .active,
                notificationsEnabled: notifyEnabled,
                notifyLeadDays: notifyEnabled ? leadDays : nil,
                notifyTime: notifyEnabled ? notifyTime : nil
            )

            // Schedule the local notification for this item (best-effort)
            if inserted.notifications_enabled {
                do {
                    try await RecurringNotificationsHelper.shared.scheduleNext(for: inserted)
                } catch {
                    #if DEBUG
                    print("Scheduling notification failed: \(error)")
                    #endif
                }
            }

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

    private func formatFriendlyDateTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d 'at' h:mm a"
        return df.string(from: date)
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

