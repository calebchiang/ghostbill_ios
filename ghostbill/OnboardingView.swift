//
//  OnboardingView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI
import Supabase

struct ProfileUpdate: Encodable {
    let currency: String
    let onboarding_complete: Bool
}

struct OnboardingView: View {
    @State private var selectedCurrency: String = "USD"
    @State private var submitting = false
    @EnvironmentObject var session: SessionStore

    var onComplete: () -> Void

    private let currencies = [
        "USD", "EUR", "GBP", "JPY", "AUD",
        "CAD", "CHF", "CNY", "SEK", "NZD",
        "MXN", "SGD", "HKD", "NOK", "KRW",
        "TRY", "INR", "RUB", "BRL", "ZAR"
    ]

    var body: some View {
        VStack(spacing: 24) {
            Text("👋 Welcome to Ghostbill")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Choose your default currency to get started")
                .foregroundColor(.secondary)

            Picker("Currency", selection: $selectedCurrency) {
                ForEach(currencies, id: \.self) { currency in
                    Text(currency).tag(currency)
                }
            }
            .pickerStyle(MenuPickerStyle())

            Button {
                Task { await completeOnboarding() }
            } label: {
                if submitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(12)
                } else {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .disabled(submitting)
            .padding(.top, 12)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func completeOnboarding() async {
        submitting = true
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id

            let update = ProfileUpdate(currency: selectedCurrency, onboarding_complete: true)

            try await SupabaseManager.shared.client
                .from("profiles")
                .update(update)
                .eq("user_id", value: userId)
                .execute()

            submitting = false
            onComplete()
        } catch {
            submitting = false
        }
    }
}

