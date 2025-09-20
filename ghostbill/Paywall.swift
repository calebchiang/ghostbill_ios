//
//  Paywall.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-18.
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    var onDismiss: () -> Void

    @StateObject private var purchases = PurchaseManager()
    @State private var isRestoring = false
    @State private var restoreMessage: String?

    private let bg = Color(red: 0.92, green: 0.94, blue: 1.0)

    // MARK: - Supabase current user id → UUID
    private func currentUserUUID() -> UUID? {
        let user = SupabaseManager.shared.client.auth.currentUser
        #if compiler(>=5.9)
        return user?.id
        #else
        if let idString = (user?.id as? String) { return UUID(uuidString: idString) }
        return nil
        #endif
    }

    // MARK: - Localized formatting helpers (use StoreKit currency)
    private func formatCurrency(_ amount: Decimal, currencyCode: String) -> String {
        let n = NSDecimalNumber(decimal: amount)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: n) ?? "\(amount)"
    }

    // Fallback when StoreProduct.currencyCode is nil
    private func currentCurrencyCodeFallback() -> String {
        if #available(iOS 16.0, *) {
            return Locale.current.currency?.identifier ?? "USD"
        } else {
            return Locale.current.currencyCode ?? "USD"
        }
    }

    // "C$3.33 / mo" derived from the yearly product price
    private func perMonthString(from yearlyPackage: Package) -> String {
        let currency = yearlyPackage.storeProduct.currencyCode
            ?? currentCurrencyCodeFallback()
        let perMonth = yearlyPackage.storeProduct.price / Decimal(12)
        return "\(formatCurrency(perMonth, currencyCode: currency)) / mo"
    }

    // 12 × monthly price, formatted using the yearly product's currency
    private func annualFullPriceString(monthlyPackage: Package, preferCurrencyFrom yearlyPackage: Package) -> String {
        let full = monthlyPackage.storeProduct.price * Decimal(12)
        let currency = yearlyPackage.storeProduct.currencyCode
            ?? currentCurrencyCodeFallback()
        return formatCurrency(full, currencyCode: currency)
    }

    // Save % computed from localized StoreKit prices
    private func savePercentString(monthlyPackage: Package, yearlyPackage: Package) -> String? {
        let full = monthlyPackage.storeProduct.price * Decimal(12)
        guard full > 0 else { return nil }
        let rate = max(Decimal(0), Decimal(1) - (yearlyPackage.storeProduct.price / full))
        let percent = (rate as NSDecimalNumber).doubleValue * 100.0
        let rounded = Int(percent.rounded())
        guard rounded > 0 else { return nil }
        return "Save \(rounded)% with yearly billing."
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 10) {
                        Text("Peace of Mind For Every Purchase.")
                            .font(.title).bold()
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)

                        if let yearly = purchases.annualPackage {
                            Text("Only \(perMonthString(from: yearly)) billed yearly.")
                                .font(.subheadline)
                                .foregroundColor(.black.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 420)
                        } else {
                            Text("Loading prices…")
                                .font(.subheadline)
                                .foregroundColor(.black.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 420)
                        }
                    }
                    .padding(.top, 80)

                    // Icons
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

                    // Benefits
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

                    // Plans
                    VStack(spacing: 14) {
                        VStack(spacing: 10) {
                            // YEARLY (localized)
                            PlanCard(
                                title: "Yearly",
                                subtitleStruck: {
                                    if let m = purchases.monthlyPackage,
                                       let y = purchases.annualPackage {
                                        return annualFullPriceString(monthlyPackage: m, preferCurrencyFrom: y)
                                    } else { return nil }
                                }(),
                                subtitle: purchases.annualPackage?.storeProduct.localizedPriceString ?? "—",
                                trailing: purchases.annualPackage.map { perMonthString(from: $0) } ?? "",
                                highlight: true,
                                badge: "Most Popular",
                                onTap: {
                                    guard let pkg = purchases.annualPackage else { return }
                                    purchases.purchase(package: pkg) { result in
                                        if case .success = result { onDismiss() }
                                        if case .failure(let e) = result { purchases.lastError = e.localizedDescription }
                                    }
                                }
                            )
                            .disabled(purchases.isLoading || purchases.annualPackage == nil)
                            .opacity((purchases.annualPackage == nil) ? 0.6 : 1)

                            // MONTHLY (localized)
                            PlanCard(
                                title: "Monthly",
                                subtitleStruck: nil,
                                subtitle: {
                                    if let m = purchases.monthlyPackage {
                                        return "\(m.storeProduct.localizedPriceString) / mo"
                                    } else { return "—" }
                                }(),
                                trailing: "",
                                highlight: false,
                                badge: nil,
                                onTap: {
                                    guard let pkg = purchases.monthlyPackage else { return }
                                    purchases.purchase(package: pkg) { result in
                                        if case .success = result { onDismiss() }
                                        if case .failure(let e) = result { purchases.lastError = e.localizedDescription }
                                    }
                                }
                            )
                            .disabled(purchases.isLoading || purchases.monthlyPackage == nil)
                            .opacity((purchases.monthlyPackage == nil) ? 0.6 : 1)
                        }

                        if purchases.isLoading {
                            ProgressView().padding(.top, 2)
                        }

                        if let err = purchases.lastError {
                            Text(err)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // Dynamic, localized savings message
                        if let m = purchases.monthlyPackage, let y = purchases.annualPackage,
                           let saveText = savePercentString(monthlyPackage: m, yearlyPackage: y) {
                            Text(saveText)
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.black.opacity(0.7))
                                .padding(.top, 4)
                        }

                        // Restore Purchases (text-only, centered)
                        VStack(spacing: 8) {
                            HStack {
                                Spacer()
                                Button {
                                    guard !isRestoring else { return }
                                    // make sure userId is set before restore
                                    if purchases.userId == nil, let uid = currentUserUUID() {
                                        purchases.setUser(id: uid)
                                    }
                                    isRestoring = true
                                    restoreMessage = nil
                                    purchases.restore { result in
                                        isRestoring = false
                                        switch result {
                                        case .success:
                                            restoreMessage = "Purchases restored."
                                        case .cancelled:
                                            break
                                        case .failure(let e):
                                            restoreMessage = "Restore failed: \(e.localizedDescription)"
                                        }
                                    }
                                } label: {
                                    if isRestoring {
                                        HStack(spacing: 6) {
                                            ProgressView().scaleEffect(0.8)
                                            Text("Restore Purchases").underline()
                                        }
                                    } else {
                                        Text("Restore Purchases").underline()
                                    }
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.blue)
                                .contentShape(Rectangle())
                                .padding(.vertical, 6)
                                Spacer()
                            }

                            if let msg = restoreMessage {
                                Text(msg)
                                    .font(.footnote)
                                    .foregroundColor(msg.contains("failed") ? .red : .green)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 0)
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
        .onAppear {
            // IMPORTANT: tie PM to the signed-in user so it can update Supabase on success/restore
            if purchases.userId == nil, let uid = currentUserUUID() {
                purchases.setUser(id: uid)
            }
            if purchases.offerings == nil && !purchases.isLoading {
                purchases.start()
            }
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
                            .stroke(highlight ? Color.indigo : Color.black.opacity(0.12),
                                    lineWidth: highlight ? 2 : 1)
                    )
                    .shadow(color: .black.opacity(highlight ? 0.12 : 0.06),
                            radius: highlight ? 18 : 10, x: 0, y: highlight ? 8 : 4)

                if let badge = badge {
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
                            if let subtitleStruck = subtitleStruck {
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

