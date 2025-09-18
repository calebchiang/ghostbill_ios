//
//  RecurringPaymentView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-17.
//

import SwiftUI
import Supabase

struct RecurringPaymentView: View {
    // Input
    let recurring: RecurringTransactionsService.DBRecurringTransaction
    var onUpdated: (RecurringTransactionsService.DBRecurringTransaction) -> Void
    var onDeleted: (UUID) -> Void

    // Local copy we can update after edits
    @State private var item: RecurringTransactionsService.DBRecurringTransaction

    // Edit state
    @State private var isEditing = false
    @State private var formMerchant: String = ""
    @State private var formAmount: String = ""
    @State private var formNextDate: Date = Date()
    @State private var formCategory: ExpenseCategory = .other
    @State private var formFrequency: RecurringTransactionsService.RecurrenceFrequency = .monthly
    @State private var formNotes: String = "" 
    @State private var formNotifyEnabled: Bool = false
    @State private var formLeadDays: Int = 3
    @State private var formNotifyTime: Date = Self.defaultNineAM()

    // UI state
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var showDeleteConfirm = false

    // Palette
    private let bg        = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let cardBG    = Color(red: 0.14, green: 0.14, blue: 0.17)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let stroke    = Color.white.opacity(0.06)
    private let indigo    = Color(red: 0.31, green: 0.27, blue: 0.90)

    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed reminder date & validation (same style as Review view)

    private var computedReminderDate: Date? {
        guard formNotifyEnabled else { return nil }
        let cal = Calendar.current
        let nextStart = cal.startOfDay(for: formNextDate)
        guard let notifyDay = cal.date(byAdding: .day, value: -formLeadDays, to: nextStart) else { return nil }
        let hm = cal.dateComponents([.hour, .minute], from: formNotifyTime)
        var comps = cal.dateComponents([.year, .month, .day], from: notifyDay)
        comps.hour = hm.hour
        comps.minute = hm.minute
        return cal.date(from: comps)
    }

    private var reminderInPast: Bool {
        guard let fire = computedReminderDate else { return false }
        return fire <= Date()
    }

    init(
        recurring: RecurringTransactionsService.DBRecurringTransaction,
        onUpdated: @escaping (RecurringTransactionsService.DBRecurringTransaction) -> Void = { _ in },
        onDeleted: @escaping (UUID) -> Void = { _ in }
    ) {
        self.recurring = recurring
        self.onUpdated = onUpdated
        self.onDeleted = onDeleted
        _item = State(initialValue: recurring)
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if let errorText {
                        Text(errorText)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .padding(.horizontal, 16)
                    }

                    if isEditing {
                        editCard
                    } else {
                        headerCard
                        detailsCard
                        notificationsCard
                    }
                }
                .padding(16)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isEditing {
                    Button("Edit") {
                        seedForm(from: item)
                        withAnimation(.easeInOut) { isEditing = true }
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isSaving)
        .confirmationDialog(
            "Delete this recurring payment?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Recurring Payment", role: .destructive) {
                Task { await deleteTapped() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Cards (Read Mode)

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(formatAmountDisplay(item.amount))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                CategoryBadge(category: item.categoryEnum)
            }

            Text(item.merchant_name.isEmpty ? "Unknown" : item.merchant_name)
                .foregroundColor(textLight)
                .font(.headline)

            Text("Next: \(formatLongDate(parseDate(item.next_date)))")
                .foregroundColor(textMuted)
                .font(.subheadline)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(cardBG))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(label: "Merchant", value: item.merchant_name)
            divider
            row(label: "Category", value: item.categoryEnum.displayName)
            divider
            row(label: "Frequency", value: item.frequency.capitalized)
            divider
            row(label: "Next Payment", value: formatLongDate(parseDate(item.next_date)))
            divider
            row(label: "Amount", value: formatAmountDisplay(item.amount), valueColor: .white)
            divider
            row(label: "Status", value: item.status.capitalized)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(cardBG))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(stroke, lineWidth: 1))
    }

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notifications")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(textMuted)

            let enabled = item.notifications_enabled
            let lead = item.notify_lead_days ?? 3
            let time = item.notify_time ?? "09:00"

            HStack {
                Text(enabled ? "On" : "Off")
                Spacer()
                Text(enabled ? "Remind \(lead) day\(lead == 1 ? "" : "s") before at \(timePrefix(time))" : "—")
                    .foregroundColor(textMuted)
            }
            .foregroundColor(textLight)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(cardBG))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(stroke, lineWidth: 1))
    }

    // MARK: - Edit UI

    private var editCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Edit Recurring")
                    .font(.title3.bold())
                    .foregroundColor(textLight)
                Spacer()
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.red)
                        .accessibilityLabel("Delete Recurring Payment")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Merchant").foregroundColor(textMuted).font(.footnote)
                TextField("Enter merchant", text: $formMerchant)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(Color.black.opacity(0.25))
                    .cornerRadius(12)
                    .foregroundColor(textLight)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Amount (numbers only)").foregroundColor(textMuted).font(.footnote)
                HStack(spacing: 8) {
                    Text("$").foregroundColor(textMuted)
                    TextField("0.00", text: $formAmount)
                        .keyboardType(.decimalPad)
                        .foregroundColor(textLight)
                }
                .padding(12)
                .background(Color.black.opacity(0.25))
                .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Category").foregroundColor(textMuted).font(.footnote)
                Picker("Select category", selection: $formCategory) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.25))
                .cornerRadius(12)
                .foregroundColor(textLight)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Frequency").foregroundColor(textMuted).font(.footnote)
                Picker("Frequency", selection: $formFrequency) {
                    Text("Daily").tag(RecurringTransactionsService.RecurrenceFrequency.daily)
                    Text("Weekly").tag(RecurringTransactionsService.RecurrenceFrequency.weekly)
                    Text("Biweekly").tag(RecurringTransactionsService.RecurrenceFrequency.biweekly)
                    Text("Monthly").tag(RecurringTransactionsService.RecurrenceFrequency.monthly)
                    Text("Yearly").tag(RecurringTransactionsService.RecurrenceFrequency.yearly)
                }
                .pickerStyle(MenuPickerStyle())
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.25))
                .cornerRadius(12)
                .foregroundColor(textLight)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Next Payment Date").foregroundColor(textMuted).font(.footnote)
                DatePicker("", selection: $formNextDate, displayedComponents: .date)
                    .labelsHidden()
                    .padding(12)
                    .background(Color.black.opacity(0.25))
                    .cornerRadius(12)
                    .colorScheme(.dark)
            }

            // Notifications (persisted; scheduling handled after update)
            VStack(alignment: .leading, spacing: 8) {
                Text("Notifications").foregroundColor(textMuted).font(.footnote)
                Toggle(isOn: $formNotifyEnabled.animation(.easeInOut(duration: 0.15))) {
                    Text("Enable reminder before next payment")
                        .foregroundColor(textLight)
                }
                .onChange(of: formNotifyEnabled) { isOn in
                    guard isOn else { return }
                    Task {
                        let allowed = await RecurringNotificationsHelper.shared.requestAuthorizationIfNeeded()
                        if !allowed {
                            await MainActor.run {
                                formNotifyEnabled = false
                                errorText = "Notifications are disabled. Enable them in Settings > Notifications > Ghostbill."
                            }
                        }
                    }
                }

                if formNotifyEnabled {
                    Picker("Remind me", selection: $formLeadDays) {
                        ForEach(1...14, id: \.self) { d in
                            Text(d == 1 ? "1 day before" : "\(d) days before").tag(d)
                        }
                    }
                    .pickerStyle(.menu)
                    .foregroundColor(textLight)

                    DatePicker("Reminder time", selection: $formNotifyTime, displayedComponents: .hourAndMinute)
                        .foregroundColor(textLight)

                    // Subtle helper text (same style as Review screen)
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
            .padding(12)
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)

            // Actions
            VStack(spacing: 10) {
                Button {
                    Task { await updateTapped() }
                } label: {
                    HStack {
                        if isSaving { ProgressView().tint(.white) }
                        Text(isSaving ? "Updating..." : "Update")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(indigo)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .disabled(isSaving || (formNotifyEnabled && reminderInPast))

                Button {
                    withAnimation(.easeInOut) { isEditing = false }
                    errorText = nil
                } label: {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundColor(textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(12)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(cardBG))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(stroke, lineWidth: 1))
    }

    // MARK: - Actions

    private func updateTapped() async {
        errorText = nil

        guard !formMerchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorText = "Merchant is required."
            return
        }
        guard let amt = parseAmount(formAmount) else {
            errorText = "Enter a valid amount (e.g., 9.99)."
            return
        }
        if formNotifyEnabled && reminderInPast {
            errorText = "Reminder time is in the past. Adjust lead days or time."
            return
        }

        guard let userId = try? await SupabaseManager.shared.client.auth.session.user.id else {
            errorText = "Not signed in."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let startOfDayNext = Calendar.current.startOfDay(for: formNextDate)

            // 1) Persist changes (including notification prefs)
            let updated = try await RecurringTransactionsService.shared.updateRecurringTransaction(
                userId: userId,
                id: item.id,
                merchantName: formMerchant,
                amount: amt,
                category: formCategory.rawValue,
                frequency: formFrequency,
                nextDate: startOfDayNext,
                // Status unchanged
                notificationsEnabled: formNotifyEnabled,
                notifyLeadDays: formNotifyEnabled ? formLeadDays : nil,
                notifyTime: formNotifyEnabled ? formNotifyTime : nil
            )

            // 2) Best-effort scheduling/cancel
            do {
                if updated.notifications_enabled {
                    _ = try await RecurringNotificationsHelper.shared.rescheduleNext(for: updated)
                } else {
                    _ = await RecurringNotificationsHelper.shared.cancel(for: updated)
                }
            } catch {
                #if DEBUG
                print("Notification scheduling failed: \(error)")
                #endif
                await MainActor.run {
                    self.errorText = "Saved, but couldn’t schedule the reminder (it may be in the past or notifications are off)."
                }
            }

            // 3) Update local state & dismiss edit
            item = updated
            onUpdated(updated)
            withAnimation(.easeInOut) { isEditing = false }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func deleteTapped() async {
        errorText = nil

        guard let userId = try? await SupabaseManager.shared.client.auth.session.user.id else {
            errorText = "Not signed in."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            // Best-effort cancel any pending notification first
            _ = await RecurringNotificationsHelper.shared.cancel(for: item)

            // Delete from DB
            try await RecurringTransactionsService.shared.deleteRecurringTransaction(
                userId: userId,
                id: item.id
            )
            onDeleted(item.id)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    // MARK: - Helpers & formatting

    private func row(label: String, value: String, valueColor: Color? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundColor(textMuted)
                .font(.subheadline)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(valueColor ?? textLight)
                .textSelection(.enabled)
        }
        .padding(.vertical, 10)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
    }

    private func seedForm(from r: RecurringTransactionsService.DBRecurringTransaction) {
        formMerchant  = r.merchant_name
        formAmount    = String(format: "%.2f", r.amount)
        formCategory  = r.categoryEnum
        formFrequency = RecurringTransactionsService.RecurrenceFrequency(rawValue: r.frequency) ?? .monthly
        formNextDate  = parseDate(r.next_date)

        formNotifyEnabled = r.notifications_enabled
        formLeadDays      = r.notify_lead_days ?? 3
        formNotifyTime    = dateFromTimeString(r.notify_time) ?? Self.defaultNineAM()
    }

    private func parseAmount(_ raw: String) -> Double? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "$", with: "")
             .replacingOccurrences(of: ",", with: "")
             .replacingOccurrences(of: " ", with: "")
        return Double(s)
    }

    private func parseDate(_ yyyyMMdd: String) -> Date {
        let f = DateFormatter()
        f.calendar = .init(identifier: .gregorian)
        f.locale = .init(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: yyyyMMdd) ?? Date()
    }

    private func formatLongDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMMM d, yyyy"
        return df.string(from: date)
    }

    private func formatAmountDisplay(_ amount: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        return nf.string(from: NSNumber(value: amount)) ?? String(format: "$%.2f", amount)
    }

    private func formatFriendlyDateTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d 'at' h:mm a"
        return df.string(from: date)
    }

    private func timePrefix(_ hhmmss: String) -> String {
        // Show HH:MM from "HH:MM" or "HH:MM:SS"
        let comps = hhmmss.split(separator: ":")
        guard comps.count >= 2 else { return hhmmss }
        return "\(comps[0]):\(comps[1])"
    }

    private func dateFromTimeString(_ s: String?) -> Date? {
        guard let s = s else { return nil }
        let parts = s.split(separator: ":").compactMap { Int($0) }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = parts.count > 0 ? parts[0] : 9
        comps.minute = parts.count > 1 ? parts[1] : 0
        return Calendar.current.date(from: comps)
    }

    private static func defaultNineAM() -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 9; comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }
}

// MARK: - Category mapping for DBRecurringTransaction
private extension RecurringTransactionsService.DBRecurringTransaction {
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

// MARK: - Pretty names
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

