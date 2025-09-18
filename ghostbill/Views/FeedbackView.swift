//
//  FeedbackView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-17.
//

import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var message: String = ""
    @State private var email: String = ""

    // Match app styling
    private let bg        = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let cardBG    = Color(red: 0.14, green: 0.14, blue: 0.17)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)

    var body: some View {
        NavigationView {
            ZStack {
                bg.ignoresSafeArea()

                VStack(spacing: 16) {

                    // Intro / description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Questions or feedback?")
                            .font(.headline)
                            .foregroundColor(textLight)
                        Text("Our team at GhostBill is committed to actively improving the product.")
                            .font(.subheadline)
                            .foregroundColor(textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16).fill(cardBG)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    .padding(.horizontal)

                    // Feedback text box
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your feedback or question")
                            .font(.subheadline)
                            .foregroundColor(textMuted)

                        ZStack(alignment: .topLeading) {
                            if message.isEmpty {
                                Text("Type here…")
                                    .foregroundColor(textMuted.opacity(0.7))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                            }
                            TextEditor(text: $message)
                                .frame(minHeight: 140)
                                .scrollContentBackground(.hidden)
                                .foregroundColor(textLight)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12).fill(cardBG)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal)

                    // Optional email
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email (optional)")
                            .font(.subheadline)
                            .foregroundColor(textMuted)
                        TextField("Enter your email if you’d like a reply", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .foregroundColor(textLight)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12).fill(cardBG)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Buttons
                    HStack(spacing: 12) {
                        Button(role: .cancel) {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray)

                        Button {
                            // Save logic to be implemented later
                            dismiss()
                        } label: {
                            Text("Save")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        // If you want to enforce non-empty feedback, uncomment:
                        // .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
