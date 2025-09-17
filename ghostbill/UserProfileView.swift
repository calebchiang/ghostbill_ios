//
//  UserProfileView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-17.
//

import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    private let bg        = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let cardBG    = Color(red: 0.14, green: 0.14, blue: 0.17)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)

    var body: some View {
        NavigationView {
            ZStack {
                bg.ignoresSafeArea()

                VStack(spacing: 16) {
                    // Placeholder profile card (you can expand later)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(textLight.opacity(0.9))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Account")
                                    .font(.headline)
                                    .foregroundColor(textLight)
                                Text("Manage your session")
                                    .font(.subheadline)
                                    .foregroundColor(textMuted)
                            }
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBG)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    .padding(.horizontal)

                    // Sign Out (red) button
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

                    Spacer()
                }
                .padding(.top, 16)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
