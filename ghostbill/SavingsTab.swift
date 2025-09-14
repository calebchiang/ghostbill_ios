//
//  SavingsTab.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI
import Supabase

// Helper wrapper so we can use .sheet(item:)
private struct SheetMonth: Identifiable, Equatable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

struct SavingsTab: View {
    // Palette
    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)

    // State
    @State private var loading = true
    @State private var data: SavingsCardData? = nil
    @State private var errorText: String? = nil

    // Sheet-driven state (month to report income for)
    @State private var sheetMonth: SheetMonth? = nil

    // Reload key for historical section
    @State private var historyReloadKey = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        Text("Savings")
                            .font(.title.bold())
                            .foregroundColor(textLight)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        // Monthly card
                        if loading {
                            MonthlySavingsCard(state: .loading)
                                .redacted(reason: .placeholder)
                                .padding(.horizontal)
                        } else if let data {
                            MonthlySavingsCard(
                                state: .loaded(data),
                                onAddIncome: {
                                    // Present sheet for the CURRENT month from the card CTA
                                    sheetMonth = SheetMonth(date: Date())
                                }
                            )
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 10) {
                                Text("Unable to load savings.")
                                    .foregroundColor(textLight)
                                if let errorText {
                                    Text(errorText)
                                        .font(.footnote)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Historical savings view (line chart + unreported list)
                        HistoricalSavingsView(
                            monthsBack: 12,
                            reloadKey: historyReloadKey,
                            onReportIncome: { month in
                                // 👉 Present sheet preset to the tapped missing month
                                sheetMonth = SheetMonth(date: month)
                            }
                        )
                        .padding(.horizontal)

                        Spacer(minLength: 24)
                    }
                    .padding(.top, 12)
                }
            }
            // Keep root screen looking identical
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { await refreshSavingsCard() }
        .sheet(item: $sheetMonth) { item in
            ReviewIncomeView(
                monthDate: item.date,
                onCancel: { sheetMonth = nil },
                onSaved: {
                    sheetMonth = nil
                    // Refresh both the monthly card and historical chart
                    Task { await refreshSavingsCard() }
                    historyReloadKey = UUID()
                }
            )
        }
    }

    // MARK: - Data

    private func refreshSavingsCard() async {
        await MainActor.run {
            self.loading = true
            self.errorText = nil
        }

        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id
            let result = try await TransactionsService.shared.getSavingsCardData(
                userId: userId,
                monthDate: Date(),
                timezone: .current
            )
            await MainActor.run {
                self.data = result
                self.loading = false
            }
        } catch {
            await MainActor.run {
                self.data = nil
                self.loading = false
                self.errorText = error.localizedDescription
            }
        }
    }
}

