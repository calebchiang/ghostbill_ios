//
//  UserProfileView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-17.
//

import SwiftUI
import Supabase

struct UserProfileView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var planName: String = "Loading…"
    @State private var showPaywall: Bool = false

    private let bg        = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let cardBG    = Color(red: 0.14, green: 0.14, blue: 0.17)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)

    var body: some View {
        NavigationView {
            ZStack {
                bg.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Profile icon
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(textLight.opacity(0.9))

                    // User info form style
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Email:")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(textLight)
                            Spacer()
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(textMuted)
                        }

                        HStack {
                            Text("Plan:")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(textLight)
                            Spacer()
                            Text(planName)
                                .font(.subheadline)
                                .foregroundColor(textMuted)
                        }

                        Button(action: { showPaywall = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color(red: 0.65, green: 0.95, blue: 0.75))
                                Text("Unlimited Access")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Color(red: 0.65, green: 0.95, blue: 0.75))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                        }
                        .padding(.top, 4)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBG)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    .padding(.horizontal)

                    Spacer()

                    // Sign Out button
                    Button {
                        session.signOut()
                        dismiss()
                    } label: {
                        Text("Sign Out")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                    .padding(.horizontal)
                }
                .padding(.top, 32)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadProfile()
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView {
                showPaywall = false
            }
        }
    }

    private func loadProfile() async {
        do {
            let supabase = SupabaseManager.shared.client
            let session = try await supabase.auth.session
            let userId = session.user.id

            await MainActor.run {
                self.email = session.user.email ?? "Unknown"
            }

            let free = try await ProfilesService.shared.isFreeUser(userId: userId)
            await MainActor.run {
                self.planName = free ? "Free Plan" : "Paid Plan"
            }
        } catch {
            await MainActor.run {
                self.email = "Unknown"
                self.planName = "Error loading plan"
            }
        }
    }
}

