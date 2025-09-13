//
//  SavingsTab.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI
import Supabase

struct SavingsTab: View {
    // Palette
    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)

    // State
    @State private var loading = true
    @State private var data: SavingsCardData? = nil
    @State private var errorText: String? = nil

    // Sheet for reporting income
    @State private var showIncomeReview = false
    @State private var monthForSheet = Date()

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if loading {
                        MonthlySavingsCard(state: .loading)
                            .redacted(reason: .placeholder)
                            .padding(.horizontal)
                    } else if let data {
                        MonthlySavingsCard(
                            state: .loaded(data),
                            onAddIncome: {
                                monthForSheet = Date()
                                showIncomeReview = true
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

                    Spacer(minLength: 24)
                }
                .padding(.top, 12)
            }
        }
        .task { await refreshSavingsCard() }
        .sheet(isPresented: $showIncomeReview) {
            ReviewIncomeView(
                monthDate: monthForSheet,
                onCancel: { showIncomeReview = false },
                onSaved: {
                    showIncomeReview = false
                    Task { await refreshSavingsCard() } // refresh after reporting income
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

