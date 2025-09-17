//
//  MainTabView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI
import UIKit

struct MainTabView: View {
    // Custom bar with a center Scan control (no label for Scan)
    enum Tab: Hashable { case home, recurring, savings, analytics }

    @State private var selected: Tab = .home

    @State private var showScanner = false
    @State private var showReview = false
    @State private var isLoadingScan = false
    @State private var scannedImage: UIImage? = nil

    @State private var ocrResult: OCRResult? = nil
    @State private var reloadKey = UUID()

    @EnvironmentObject var session: SessionStore

    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let barBG = Color(red: 0.12, green: 0.12, blue: 0.14)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color.white.opacity(0.6)
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)
    private let indigoSelected = Color(red: 0.45, green: 0.42, blue: 0.95)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ==== CONTENT AREA ====
                Group {
                    switch selected {
                    case .home:
                        HomeTab(reloadKey: reloadKey)
                    case .recurring:
                        RecurringTab()
                    case .savings:
                        SavingsTab()
                    case .analytics:
                        AnalyticsTab()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // ==== CUSTOM TAB BAR ====
                CustomTabBar(
                    selected: $selected,
                    barBG: barBG,
                    indigo: indigo,
                    indigoSelected: indigoSelected,
                    textLight: textLight,
                    textMuted: textMuted,
                    onScanTapped: { showScanner = true }
                )
            }

            // Loading overlay during OCR
            if isLoadingScan {
                ZStack {
                    bg.ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: indigo))
                            .scaleEffect(1.5)
                        Text("Processing receipt…")
                            .foregroundColor(textLight)
                            .font(.headline)
                    }
                }
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            ReceiptScannerView(
                onComplete: { images in
                    scannedImage = images.first
                    showScanner = false
                    guard let img = scannedImage else { return }

                    print("📸 Scanned image: \(Int(img.size.width))x\(Int(img.size.height)) @\(img.scale)x, orientation=\(img.imageOrientation.rawValue)")

                    isLoadingScan = true
                    Task {
                        do {
                            let result = try await ReceiptOCR.shared.extract(from: img)
                            print("🧾 OCR MERCHANT:", result.merchant ?? "nil")
                            print("🧾 OCR AMOUNT:", result.amount ?? "nil")
                            if let d = result.date {
                                print("🧾 OCR DATE:", d.description)
                            } else {
                                print("🧾 OCR DATE: nil")
                            }
                            print("🧾 OCR CATEGORY:", result.category.rawValue, "(confidence:", result.categoryConfidence, ")")
                            print("🧾 OCR RAW TEXT BEGIN =======================")
                            print(result.rawText)
                            print("🧾 OCR RAW TEXT END   =======================")

                            ocrResult = result
                            isLoadingScan = false
                            showReview = true
                        } catch {
                            print("❌ OCR ERROR:", error.localizedDescription)
                            ocrResult = nil
                            isLoadingScan = false
                            showReview = true
                        }
                    }
                },
                onCancel: {
                    showScanner = false
                },
                onError: { err in
                    print("❌ Camera error:", err.localizedDescription)
                    showScanner = false
                },
                onManualAdd: {
                    showScanner = false
                    isLoadingScan = false
                    scannedImage = nil
                    ocrResult = nil
                    showReview = true
                }
            )
        }
        .sheet(isPresented: $showReview) {
            ReviewTransactionView(
                initialMerchant: ocrResult?.merchant,
                initialAmount: ocrResult?.amount,
                initialDate: ocrResult?.date,
                initialCategory: ocrResult?.category,
                onSave: { merchant, amountString, pickedDate, category, note in
                    Task {
                        guard let amountString, let parsed = parseAmount(amountString) else {
                            print("❌ Save error: invalid amount '\(amountString ?? "nil")'")
                            return
                        }
                        let amountToStore = -abs(parsed)

                        do {
                            let session = try await SupabaseManager.shared.client.auth.session
                            let userId = session.user.id
                            let currency = (try? await TransactionsService.shared.fetchProfileCurrency(userId: userId)) ?? "USD"
                            let dateToStore = pickedDate ?? Date()

                            let inserted = try await TransactionsService.shared.insertTransaction(
                                userId: userId,
                                amount: amountToStore,
                                currency: currency,
                                date: dateToStore,
                                merchant: (merchant?.isEmpty == true) ? nil : merchant,
                                category: category,
                                note: (note?.isEmpty == true) ? nil : note
                            )

                            print("✅ Saved transaction:", inserted.id, inserted.amount, inserted.currency, inserted.date)

                            await MainActor.run {
                                reloadKey = UUID()
                                selected = .home
                                showReview = false
                                scannedImage = nil
                                ocrResult = nil
                            }
                        } catch {
                            print("❌ Insert error:", error.localizedDescription)
                        }
                    }
                },
                onScanAgain: {
                    showReview = false
                    scannedImage = nil
                    ocrResult = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showScanner = true
                    }
                },
                onCancel: {
                    showReview = false
                    scannedImage = nil
                    ocrResult = nil
                }
            )
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

// MARK: - Custom Tab Bar

private struct CustomTabBar: View {
    @Binding var selected: MainTabView.Tab

    let barBG: Color
    let indigo: Color
    let indigoSelected: Color
    let textLight: Color
    let textMuted: Color

    let onScanTapped: () -> Void

    var body: some View {
        GeometryReader { geo in
            let bottomInset = geo.safeAreaInsets.bottom

            VStack(spacing: 0) {
                // subtle top divider
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                HStack {
                    // Home
                    tabButton(
                        system: selected == .home ? "house.fill" : "house",
                        label: "Home",
                        isSelected: selected == .home
                    ) { selected = .home }

                    // Recurring
                    tabButton(
                        system: "repeat.circle.fill",
                        label: "Recurring",
                        isSelected: selected == .recurring
                    ) { selected = .recurring }

                    // Scan (center) — circle button with no label
                    Button(action: onScanTapped) {
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(indigo)
                            .clipShape(Circle())
                            .shadow(color: indigo.opacity(0.4), radius: 12, x: 0, y: 8)
                            .accessibilityLabel("Scan receipt")
                    }
                    .frame(maxWidth: .infinity)

                    // Savings
                    tabButton(
                        system: "banknote.fill",
                        label: "Savings",
                        isSelected: selected == .savings
                    ) { selected = .savings }

                    // Analytics
                    tabButton(
                        system: "chart.bar.xaxis",
                        label: "Analytics",
                        isSelected: selected == .analytics
                    ) { selected = .analytics }
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, max(bottomInset, 10))
                .background(barBG.ignoresSafeArea(edges: .bottom))
            }
        }
        .frame(height: 60) // base; actual height grows with safe-area padding
    }

    // Tab button helper (icon + label)
    private func tabButton(system: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: system)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? indigoSelected : textMuted)
                Text(label)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? indigoSelected : textMuted)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .accessibilityLabel(label)
        }
        .buttonStyle(.plain)
    }
}

