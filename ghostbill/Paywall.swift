//
//  Paywall.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-18.
//

import SwiftUI

struct PaywallView: View {
    var onDismiss: () -> Void

    private let bg = Color(red: 0.92, green: 0.94, blue: 1.0)

    private let monthlyPrice: Decimal = 4.99
    private let discountRate: Decimal = 0.30

    private func forceEnding99(_ value: Decimal) -> Decimal {
        var v = value
        var floored = Decimal()
        NSDecimalRound(&floored, &v, 0, .down)
        return floored - Decimal(0.01)
    }
    private func forceEnding49(_ value: Decimal) -> Decimal {
        var v = value
        var floored = Decimal()
        NSDecimalRound(&floored, &v, 0, .down)
        return floored + Decimal(0.49)
    }

    private func money(_ value: Decimal) -> String {
        let n = NSDecimalNumber(decimal: value)
        let f = NumberFormatter()
        f.numberStyle = .currency
        if #available(iOS 16.0, *) {
            f.currencyCode = Locale.current.currency?.identifier ?? "USD"
        } else {
            f.currencyCode = Locale.current.currencyCode ?? "USD"
        }
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: n) ?? "$\(n)"
    }

    private var annualFullDisplay: Decimal { Decimal(5.00) * 12 }
    private var annualDiscountedDisplay: Decimal {
        forceEnding99(annualFullDisplay * (Decimal(1) - discountRate))
    }
    private var annualPerMonthDisplay: Decimal {
        forceEnding49(annualDiscountedDisplay / Decimal(12))
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        Text("Understand where your money goes.")
                            .font(.title).bold()
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)

                        Text("Only \(money(annualPerMonthDisplay)) per month billed yearly.")
                            .font(.subheadline)
                            .foregroundColor(.black.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 420)
                    }
                    .padding(.top, 80)

                    HStack(spacing: 14) {
                        RoundedIconContainer(imageName: "calendar_icon",
                                             bgColor: Color(red: 0.86, green: 0.90, blue: 1.00))
                        RoundedIconContainer(imageName: "piggybank_filled",
                                             bgColor: Color(red: 1.00, green: 0.92, blue: 0.97))
                        RoundedIconContainer(imageName: "analysis_icon",
                                             bgColor: Color(red: 0.90, green: 1.00, blue: 0.94))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)

                    VStack(spacing: 12) {
                        Text("Keep your finances clear and stress-free.")
                            .font(.title3).bold()
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)

                        VStack(alignment: .leading, spacing: 10) {
                            BenefitRow(text: "Unlimited receipt scans")
                            BenefitRow(text: "Smart auto-categorization")
                            BenefitRow(text: "Clear monthly insights & trends")
                            BenefitRow(text: "Manage recurring payments and subscriptions")
                            BenefitRow(text: "Priority feature access")
                        }
                        .frame(maxWidth: 300, alignment: .leading)
                    }

                    VStack(spacing: 14) {
                        VStack(spacing: 10) {
                            PlanCard(
                                title: "Yearly",
                                subtitleStruck: money(annualFullDisplay),
                                subtitle: money(annualDiscountedDisplay),
                                trailing: "\(money(annualPerMonthDisplay)) / mo",
                                highlight: true,
                                badge: "Most Popular",
                                onTap: {} // no-op
                            )

                            PlanCard(
                                title: "Monthly",
                                subtitleStruck: nil,
                                subtitle: "\(money(monthlyPrice)) / mo",
                                trailing: "",
                                highlight: false,
                                badge: nil,
                                onTap: {} // no-op
                            )
                        }

                        Text("Save 30% with yearly billing.")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.black.opacity(0.7))
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: 520)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .overlay(alignment: .topLeading) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black.opacity(0.7))
                        .padding(12)
                        .background(Color.white.opacity(0.7), in: Circle())
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .allowsHitTesting(true)
        }
    }
}

private struct RoundedIconContainer: View {
    let imageName: String
    let bgColor: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(bgColor)
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .shadow(radius: 2, x: 0, y: 1)
        }
        .frame(width: 92, height: 72)
    }
}

private struct BenefitRow: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
            Text(text)
                .foregroundColor(.black)
        }
        .font(.subheadline)
    }
}

private struct PlanCard: View {
    let title: String
    let subtitleStruck: String?
    let subtitle: String
    let trailing: String
    let highlight: Bool
    let badge: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(highlight ? Color.indigo : Color.black.opacity(0.12), lineWidth: highlight ? 2 : 1)
                    )
                    .shadow(color: .black.opacity(highlight ? 0.12 : 0.06), radius: highlight ? 18 : 10, x: 0, y: highlight ? 8 : 4)

                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule(style: .continuous).fill(Color.indigo))
                        .foregroundColor(.white)
                        .offset(x: -10, y: -10)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.headline).foregroundColor(.black)
                        HStack(spacing: 6) {
                            if let subtitleStruck {
                                Text(subtitleStruck)
                                    .foregroundColor(.black.opacity(0.45))
                                    .strikethrough()
                            }
                            Text(subtitle)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                        }
                    }
                    Spacer(minLength: 12)
                    if !trailing.isEmpty {
                        Text(trailing)
                            .font(.subheadline)
                            .foregroundColor(.black.opacity(0.7))
                    }
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

