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

    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    var onCancel: () -> Void
    var onSaved: () -> Void

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

    private enum Field { case merchant, amount }
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    Section(header: Text("Merchant")) {
                        TextField("e.g. Netflix, Rent", text: $merchantName)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .merchant)
                    }

                    Section(header: Text("Amount")) {
                        TextField("e.g. 9.99", text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .amount)
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
                .scrollDismissesKeyboard(.interactively)

                if showToast {
                    VStack {
                        HStack(spacing: 10) {
                            Image(systemName: toastIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(.white)
                                .imageScale(.large)
                            Text(toastMessage)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(toastIsError ? Color.red.opacity(0.9) : Color.green.opacity(0.9))
                        )
                        .padding(.top, 40)
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 4)
                        .ignoresSafeArea(.keyboard)

                        Spacer()
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.9), value: showToast)
                }
            }
            .simultaneousGesture(TapGesture().onEnded { focusedField = nil })
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
            errorText = "Reminder time is in the past. Adjust lead days or time."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id

            let isFree = try await ProfilesService.shared.isFreeUser(userId: userId)
            if isFree {
                let remaining = try await TransactionCheckerService.shared.remainingFreeTransactions(userId: userId)
                if remaining <= 0 {
                    await MainActor.run {
                        toastMessage = "Free plan limit reached. Upgrade to add more."
                        toastIsError = true
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            showToast = true
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showToast = false
                        }
                    }
                    return
                }
            }

            let startOfDay = Calendar.current.startOfDay(for: nextDate)

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

            if inserted.notifications_enabled {
                do { try await RecurringNotificationsHelper.shared.scheduleNext(for: inserted) }
                catch { print("Scheduling notification failed: \(error)") }
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
        case .personal:      return "Personal"
        case .income:        return "Income"
        case .other:         return "Other"
        }
    }
}

