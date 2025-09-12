//
//  MainTabView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable { case home, recurring, savings, analytics }

    @State private var selected: Tab = .home
    @State private var showScanner = false
    @State private var showReview = false
    @State private var isLoadingScan = false
    @State private var scannedImage: UIImage? = nil

    // OCR result used to prefill the review screen
    @State private var ocrResult: OCRResult? = nil

    @State private var reloadKey = UUID()

    @EnvironmentObject var session: SessionStore

    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            TabView(selection: $selected) {
                // 👇 Pass reloadKey down so HomeTab reloads when this changes
                HomeTab(reloadKey: reloadKey)
                    .tag(Tab.home)
                    .tabItem {
                        Image(systemName: selected == .home ? "house.fill" : "house")
                        Text("Home")
                    }

                RecurringTab()
                    .tag(Tab.recurring)
                    .tabItem {
                        Image(systemName: "repeat.circle")
                        Text("Recurring")
                    }

                SavingsTab()
                    .tag(Tab.savings)
                    .tabItem {
                        Image(systemName: "banknote")
                        Text("Savings")
                    }

                AnalyticsTab()
                    .tag(Tab.analytics)
                    .tabItem {
                        Image(systemName: "chart.bar.xaxis")
                        Text("Analytics")
                    }
            }
            .tint(indigo)
            .toolbarBackground(bg, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)
            .background(bg.ignoresSafeArea()) 

            VStack {
                Spacer()
                Button {
                    showScanner = true
                } label: {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(indigo)
                        .clipShape(Circle())
                        .shadow(color: indigo.opacity(0.4), radius: 12, x: 0, y: 8)
                }
                .padding(.bottom, 30)
                .accessibilityLabel("Scan receipt")
            }
            .allowsHitTesting(true)

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

                    // Log basic image info
                    print("📸 Scanned image: \(Int(img.size.width))x\(Int(img.size.height)) @\(img.scale)x, orientation=\(img.imageOrientation.rawValue)")

                    isLoadingScan = true
                    Task {
                        do {
                            let result = try await ReceiptOCR.shared.extract(from: img)

                            // ==== DEBUG LOGS (OCR FIELDS) ====
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
                            // Log the failure and still open review for manual edit
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
                        // Parse amount
                        guard let amountString, let parsed = parseAmount(amountString) else {
                            print("❌ Save error: invalid amount '\(amountString ?? "nil")'")
                            return
                        }
                        // Always store as negative (expense)
                        let amountToStore = -abs(parsed)

                        do {
                            // Get current user id
                            let session = try await SupabaseManager.shared.client.auth.session
                            let userId = session.user.id

                            // Fetch currency from profile (fallback to "USD")
                            let currency = (try? await TransactionsService.shared.fetchProfileCurrency(userId: userId)) ?? "USD"

                            // Use selected date or today
                            let dateToStore = pickedDate ?? Date()

                            // Insert
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

                            // 👉 Force Home to refresh & jump to Home tab
                            await MainActor.run {
                                reloadKey = UUID()
                                selected = .home
                                // Clean up & dismiss
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

    // MARK: - Helpers

    /// Parses strings like "$237.44", "237.44", "(237.44)" → Double
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

