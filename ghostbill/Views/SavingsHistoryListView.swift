//
//  SavingsHistoryListView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-13.
//

import SwiftUI
import Supabase

struct SavingsHistoryListView: View {
    // Inputs
    var monthsBack: Int = 24
    var reloadKey: UUID = UUID()
    /// Called when the user taps "Report" for a missing-income month.
    var onReportIncome: ((Date) -> Void)?

    // State
    @State private var loading = true
    @State private var history: SavingsHistory? = nil
    @State private var errorText: String? = nil

    // Style
    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let cardBG = Color(red: 0.14, green: 0.14, blue: 0.17)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let accent = Color.mint

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(accent)
                    Text("Savings by month")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(textLight)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Content
                Group {
                    if loading {
                        VStack(spacing: 10) {
                            ForEach(0..<6, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 60)
                                    .shimmering() // subtle effect
                            }
                        }
                        .padding(.horizontal, 16)
                    } else if let rows = combinedRows(), !rows.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(rows, id: \.date) { row in
                                    rowView(row)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 28))
                                .foregroundColor(textMuted.opacity(0.8))
                            Text("No months to show yet")
                                .foregroundColor(textMuted)
                                .font(.subheadline)
                            Text("Add some transactions and report income to see monthly savings here.")
                                .foregroundColor(textMuted.opacity(0.9))
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
        }
        .task(id: reloadKey) { await loadHistory() }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Row Model

    private struct RowModel {
        let date: Date
        let hasIncome: Bool
        let savings: Double?
    }

    private func combinedRows() -> [RowModel]? {
        guard let h = history else { return nil }

        var byMonth: [Date: RowModel] = [:]

        for p in h.reported {
            byMonth[p.monthStart] = RowModel(date: p.monthStart, hasIncome: true, savings: p.savings)
        }
        for m in h.unreported {
            if byMonth[m] == nil {
                byMonth[m] = RowModel(date: m, hasIncome: false, savings: nil)
            }
        }

        return byMonth.values.sorted(by: { $0.date > $1.date })
    }

    // MARK: - Views

    @ViewBuilder
    private func rowView(_ row: RowModel) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(monthLabel(row.date))
                    .foregroundColor(textLight)
                    .font(.subheadline.weight(.semibold))

                if !row.hasIncome {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("No income reported")
                            .foregroundColor(.orange)
                            .font(.caption2)
                    }
                }
            }

            Spacer()

            if let val = row.savings, row.hasIncome {
                HStack(spacing: 4) {
                    // Plain dollar sign, same color and size as the value
                    Text("$")
                        .foregroundColor(textLight)
                        .font(.headline)
                    Text(formatNumber(val))
                        .foregroundColor(textLight)
                        .font(.headline)
                }
                .accessibilityLabel("Saved \(formatNumber(val))")
            } else {
                Button {
                    onReportIncome?(row.date)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Report")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundColor(textLight)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(accent.opacity(0.18))
                    )
                }
                .accessibilityLabel("Report income for \(monthLabel(row.date))")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(cardBG)
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Data

    private func loadHistory() async {
        await MainActor.run {
            loading = true
            errorText = nil
            history = nil
        }

        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id

            let result = try await TransactionsService.shared.getSavingsHistory(
                userId: userId,
                monthsBack: monthsBack,
                now: Date(),
                timezone: .current
            )
            await MainActor.run {
                history = result
                loading = false
            }
        } catch {
            await MainActor.run {
                loading = false
                errorText = error.localizedDescription
            }
        }
    }

    // MARK: - Helpers

    private func monthLabel(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        return df.string(from: date)
    }

    private func formatNumber(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        nf.minimumFractionDigits = 0
        return nf.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

// MARK: - Shimmer Modifier

extension View {
    func shimmering() -> some View {
        self.overlay(
            LinearGradient(
                gradient: Gradient(colors: [Color.white.opacity(0), Color.white.opacity(0.2), Color.white.opacity(0)]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .rotationEffect(.degrees(20))
            .offset(x: -150)
            .frame(width: 200)
            .mask(self)
            .animation(Animation.linear(duration: 1.2).repeatForever(autoreverses: false), value: UUID())
        )
    }
}

