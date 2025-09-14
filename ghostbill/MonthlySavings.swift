//
//  MonthlySavings.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-13.
//

import SwiftUI

private func monthLabel(from date: Date) -> String {
    let df = DateFormatter()
    df.dateFormat = "LLLL yyyy"
    return df.string(from: date)
}

enum MonthlyCardState {
    case loading
    case loaded(SavingsCardData)
}

struct MonthlySavingsCard: View {
    // Inputs
    let state: MonthlyCardState
    var onAddIncome: (() -> Void)? = nil

    // Palette
    private let cardBG = Color(red: 0.14, green: 0.14, blue: 0.17)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let good = Color.green.opacity(0.9)

    var body: some View {
        let headerMonth: String = {
            switch state {
            case .loading:
                return monthLabel(from: Date())
            case .loaded(let d):
                return monthLabel(from: d.monthStart)
            }
        }()

        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: "banknote.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Total saved this month")
                        .font(.headline)
                        .foregroundColor(textLight)
                    Text(headerMonth)
                        .font(.subheadline)
                        .foregroundColor(textMuted)
                }

                Spacer()
            }

            // Content
            switch state {
            case .loading:
                VStack(alignment: .leading, spacing: 8) {
                    Text("0")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(good)
                    HStack {
                        Text("Income")
                            .foregroundColor(textMuted)
                        Spacer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 80, height: 14)
                    }
                    HStack {
                        Text("Spending")
                            .foregroundColor(textMuted)
                        Spacer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 80, height: 14)
                    }
                }

            case .loaded(let d):
                if d.hasIncome == false {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No income reported for \(headerMonth).")
                            .font(.subheadline)
                            .foregroundColor(textMuted)

                        if let onAddIncome {
                            Button(action: onAddIncome) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Add income for \(headerMonth)")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundColor(textLight)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.green.opacity(0.22))
                                )
                            }
                        }
                    }
                } else {
                    // ---- UI-only clamp rule ----
                    let savedRaw = d.savings            // may be negative from service
                    let saved = max(0, savedRaw)        // never below 0 in UI
                    let overspent = max(0, -savedRaw)   // positive when spending > income

                    // Big savings number (clamped)
                    Text(formatNumber(saved))
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(saved == 0 ? textMuted : good)

                    // Optional overspent note
                    if overspent > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("Overspent by \(formatNumber(overspent))")
                                .font(.footnote)
                                .foregroundColor(.orange)
                        }
                    }

                    // Breakdown
                    VStack(spacing: 8) {
                        HStack {
                            Text("Income")
                                .foregroundColor(textMuted)
                            Spacer()
                            Text(formatNumber(d.income))
                                .foregroundColor(textLight)
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("Spending")
                                .foregroundColor(textMuted)
                            Spacer()
                            Text(formatNumber(d.spending))
                                .foregroundColor(textLight)
                                .fontWeight(.semibold)
                        }
                        Divider().background(Color.white.opacity(0.08))
                        HStack {
                            Text("Savings")
                                .foregroundColor(textMuted)
                            Spacer()
                            Text(formatNumber(saved)) // clamped value
                                .foregroundColor(saved == 0 ? textMuted : good)
                                .fontWeight(.bold)
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(cardBG)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Helpers

    private func formatNumber(_ value: Double) -> String {
        // Plain number with grouping, no currency symbol
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        nf.minimumFractionDigits = 0
        return nf.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private var accessibilityText: String {
        switch state {
        case .loading:
            return "Loading savings card"
        case .loaded(let d):
            let month = monthLabel(from: d.monthStart)
            if d.hasIncome == false {
                return "No income reported for \(month)."
            } else {
                let saved = max(0, d.savings)
                return "Total saved this month \(month): \(Int(saved))"
            }
        }
    }
}

