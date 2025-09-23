//
//  UserProfileView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-17.
//

import SwiftUI
import Supabase
import RevenueCat

struct UserProfileView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var planName: String = "Loading…"
    @State private var showPaywall: Bool = false
    @State private var showDeleteAlert: Bool = false

    @State private var isFreeUser: Bool = true

    private let bg        = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let cardBG    = Color(red: 0.14, green: 0.14, blue: 0.17)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)

    var body: some View {
        NavigationView {
            ZStack {
                bg.ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(textLight.opacity(0.9))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Email:")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(textLight)
                            Spacer()
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(textMuted)
                                .lineLimit(1)
                                .truncationMode(.middle)
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

                        if isFreeUser {
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
                        } else {
                            Button {
                                Purchases.shared.showManageSubscriptions { error in
                                    if let error {
                                        print("Manage subscriptions error: \(error.localizedDescription)")
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "gearshape.fill")
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(Color(red: 0.65, green: 0.85, blue: 0.95))
                                    Text("Manage Subscription")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(Color(red: 0.65, green: 0.85, blue: 0.95))
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

                    Text("Dangerous Actions")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(textLight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            showDeleteAlert = true
                        } label: {
                            Text("Delete Account")
                                .font(.subheadline.weight(.semibold))
                                .underline()
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
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
                    .alert("Delete Account?", isPresented: $showDeleteAlert) {
                        Button("Delete Account", role: .destructive) {
                            Task {
                                do {
                                    let client = SupabaseManager.shared.client
                                    _ = try await client.functions.invoke("hyper-api") as Void
                                    await MainActor.run {
                                        session.signOut()
                                        dismiss()
                                    }
                                } catch {
                                    print("Delete account failed:", error.localizedDescription)
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will permanently delete your account and all associated data. This action cannot be undone.")
                    }

                    HStack(spacing: 12) {
                        Link("Privacy Policy", destination: URL(string: "https://ghostbill.com/privacy")!)
                        Text("•")
                        Link("Terms & Conditions", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula")!)
                    }
                    .font(.caption)
                    .foregroundColor(textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal)
                    Spacer()

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
                Task { await loadProfile() }
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
                self.isFreeUser = free
                self.planName = free ? "Free Plan" : "Paid Plan"
            }
        } catch {
            await MainActor.run {
                self.email = "Unknown"
                self.planName = "Error loading plan"
                self.isFreeUser = true
            }
        }
    }
}

