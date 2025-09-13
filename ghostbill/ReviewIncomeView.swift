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
    @State private var isSaving = false
    @State private var errorText: String?

    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)       // overall background
    private let cardBG = Color(red: 0.14, green: 0.14, blue: 0.17)   // card background
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let stroke = Color.white.opacity(0.06)
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

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
                    Text(monthLabel(monthDate))
                        .font(.subheadline)
                        .foregroundColor(textMuted)
                }

                Text("Enter your income to calculate your savings for this month.")
                    .font(.footnote)
                    .foregroundColor(textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 6)

            // Card with single input
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
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(bg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(stroke, lineWidth: 1)
                )

                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.top, 2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(bg)
            )
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Spacer(minLength: 12)

            VStack(spacing: 10) {
                Button {
                    Task { await save() }
                } label: {
                    Text(isSaving ? "Saving…" : "Save income")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(indigo)
                        )
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
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.04))
                        )
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
    }

    // MARK: - Actions

    private func save() async {
        errorText = nil

        guard let amount = parseAmount(amountText), amount > 0 else {
            errorText = "Enter a valid amount (e.g., 2500.00)."
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
                note: nil
            )

            await MainActor.run { onSaved() }
        } catch {
            await MainActor.run { errorText = error.localizedDescription }
        }
    }

    private func monthLabel(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
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

