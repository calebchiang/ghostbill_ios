//
//  ContentView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-09.
//

import SwiftUI
import Supabase

struct ContentView: View {
    @State private var email: String = ""
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @FocusState private var emailFocused: Bool
    @Environment(\.supabaseClient) private var supabase

    var body: some View {
        ZStack {
            Color(red: 0.09, green: 0.09, blue: 0.11)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Text("GhostBill")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.96, green: 0.96, blue: 0.96))
                    .padding(.bottom, 28)

                Text("Track your expenses, build better spending habits.")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.80, green: 0.80, blue: 0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .frame(maxWidth: 420)
                    .padding(.bottom, 40)

                Text("Get started")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.72, green: 0.72, blue: 0.76))
                    .padding(.bottom, 8)

                VStack(spacing: 12) {
                    TextField("Email", text: $email, prompt: Text("Email"))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled(true)
                        .foregroundColor(Color(red: 0.96, green: 0.96, blue: 0.96))
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(Color(red: 0.13, green: 0.13, blue: 0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.22, green: 0.22, blue: 0.25), lineWidth: 1)
                        )
                        .cornerRadius(12)
                        .focused($emailFocused)

                    Button(action: {
                        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        emailFocused = false
                        Task {
                            do {
                                try await supabase.auth.signInWithOTP(
                                    email: trimmed,
                                    redirectTo: URL(string: AppConfig.redirectURLString)
                                )
                                await MainActor.run {
                                    toastMessage = "Check your email and click the link to log in."
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        showToast = true
                                    }
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        showToast = false
                                    }
                                }
                            } catch {
                                print("Failed to send magic link: \(error)")
                            }
                        }
                    }) {
                        Text("Continue")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .background(Color(red: 0.31, green: 0.27, blue: 0.90))
                    .cornerRadius(40)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: 420)

                Text("Sign in with")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.72, green: 0.72, blue: 0.76))
                    .padding(.top, 18)

                Button(action: {}) {
                    Image("google_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .padding(8)
                        .background(Circle().fill(Color.white))
                }
                .frame(width: 44, height: 44)
                .padding(.top, 6)

                Spacer()

                FloatingGhostView()
                .padding(.bottom, 140)
            }
            .padding(.top, 65)
        }
        .overlay(alignment: .top) {
            if showToast {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .imageScale(.large)
                    Text(toastMessage)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)   
                        .fill(Color.green.opacity(0.9))
                )
                .padding(.top, 40)
                .padding(.horizontal, 24)
                .transition(.move(edge: .top).combined(with: .opacity))
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 4)
                .ignoresSafeArea(.keyboard)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

