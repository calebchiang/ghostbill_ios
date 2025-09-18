//
//  ReviewIncomeView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-13.
//

import SwiftUI
import Supabase

struct ReviewIncomeView: View {
    // MARK: - Props
    let monthDate: Date
    var onCancel: () -> Void
    var onSaved: () -> Void

    // MARK: - State
    @State private var amountText: String = ""
    @State private var dayText: String = ""
    @State private var isSaving = false
    @State private var errorText: String?

    // Palette
    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let cardBG = Color(red: 0.14, green: 0.14, blue: 0.17)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let stroke = Color.white.opacity(0.06)
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Grabber
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 42, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 8)

            // Title + subtle description
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Report income")
                        .font(.title2.bold())
                        .foregroundColor(textLight)
                    Text(fullMonthLabel(monthDate))
                        .font(.subheadline)
                        .foregroundColor(textMuted)
                }

                Text("Enter your income for this month.")
                    .font(.footnote)
                    .foregroundColor(textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 24)

            // Card with inputs
            VStack(alignment: .leading, spacing: 16) {
                // Amount
                VStack(alignment: .leading, spacing: 12) {
                    Text("Amount")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(textMuted)

                    HStack(spacing: 10) {
                        Text("$")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(textMuted)

                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(textLight)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(bg))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(stroke, lineWidth: 1))
                }

                // Simple manual day input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pay date")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(textMuted)

                    HStack(spacing: 10) {
                        // Abbreviated month label (e.g., "Sep")
                        Text(monthAbbrev(monthDate))
                            .font(.body.weight(.semibold))
                            .foregroundColor(textLight)

                        // Day number input
                        TextField("DD", text: dayBindingLimited)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(textLight)
                            .frame(width: 60, alignment: .leading)
                            .multilineTextAlignment(.leading)

                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(bg))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(stroke, lineWidth: 1))
                }

                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(cardBG))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.05), lineWidth: 1))
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Spacer(minLength: 12)

            // Actions
            VStack(spacing: 10) {
                Button {
                    Task { await save() }
                } label: {
                    Text(isSaving ? "Saving…" : "Save income")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(indigo))
                }
                .disabled(isSaving)

                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
                }
                .disabled(isSaving)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .background(bg.ignoresSafeArea())
        .interactiveDismissDisabled(isSaving)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            // Default the day to "today" if it's in this month, otherwise "1"
            let cal = Calendar(identifier: .gregorian)
            let sameMonth = cal.isDate(monthDate, equalTo: Date(), toGranularity: .month)
            if sameMonth {
                let day = cal.component(.day, from: Date())
                dayText = "\(min(max(1, day), daysInMonth))"
            } else {
                dayText = "1"
            }
        }
    }

    // MARK: - Derived values & bindings

    private var daysInMonth: Int {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: cal.dateComponents([.year, .month], from: monthDate)) ?? monthDate
        return cal.range(of: .day, in: .month, for: start)?.count ?? 31
    }

    // Sanitize day input to digits only and limit length
    private var dayBindingLimited: Binding<String> {
        Binding<String>(
            get: { dayText },
            set: { newVal in
                // keep digits only
                let digits = newVal.filter { $0.isNumber }
                // limit to 2 chars (enough for all months)
                let trimmed = String(digits.prefix(2))
                dayText = trimmed
            }
        )
    }

    // MARK: - Actions

    private func save() async {
        errorText = nil

        guard let amount = parseAmount(amountText), amount > 0 else {
            errorText = "Enter a valid amount (e.g., 2500.00)."
            return
        }

        // Validate and build date from the (year, month) of monthDate and the entered day
        guard let day = Int(dayText), (1...daysInMonth).contains(day) else {
            errorText = "Day must be between 1 and \(daysInMonth)."
            return
        }

        // Build the actual date
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        var comps = cal.dateComponents([.year, .month], from: monthDate)
        comps.day = day
        guard let selectedDate = cal.date(from: comps) else {
            errorText = "Could not build a valid date."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id

            _ = try await TransactionsService.shared.insertIncomeForMonth(
                userId: userId,
                amount: amount,
                monthDate: monthDate,
                timezone: .current,
                note: nil,
                onDate: selectedDate
            )

            await MainActor.run { onSaved() }
        } catch {
            await MainActor.run { errorText = error.localizedDescription }
        }
    }

    // MARK: - Formatting & parsing

    private func fullMonthLabel(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        return df.string(from: date)
    }

    private func monthAbbrev(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "LLL"
        return df.string(from: date)
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

