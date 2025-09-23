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
    @State private var password: String = ""
    @State private var showPasswordPrompt: Bool = false
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var isErrorToast: Bool = false
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

                    if showPasswordPrompt {
                        SecureField("Password", text: $password, prompt: Text("Password"))
                            .textInputAutocapitalization(.never)
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
                    }

                    if showPasswordPrompt {
                        Button(action: {
                            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            emailFocused = false
                            Task {
                                do {
                                    _ = try await supabase.auth.signIn(email: trimmed, password: password)
                                } catch {
                                    await showErrorToast("Login failed. Please try again.")
                                }
                            }
                        }) {
                            Text("Sign In")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .background(Color(red: 0.31, green: 0.27, blue: 0.90))
                        .cornerRadius(40)
                    } else {
                        Button(action: {
                            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            emailFocused = false
                            if trimmed.lowercased() == "review@ghostbill.com" {
                                withAnimation { showPasswordPrompt = true }
                                return
                            }
                            Task {
                                do {
                                    try await supabase.auth.signInWithOTP(
                                        email: trimmed,
                                        redirectTo: URL(string: AppConfig.redirectURLString)
                                    )
                                    await showSuccessToast("Check your email and click the link to log in.")
                                } catch {
                                    await showErrorToast("Failed to send magic link.")
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
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: 420)

                Text("Sign in with")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.72, green: 0.72, blue: 0.76))
                    .padding(.top, 18)

                HStack(spacing: 12) {
                    // Google Sign In
                    Button(action: {
                        emailFocused = false
                        Task {
                            do {
                                let redirect = URL(string: AppConfig.redirectURLString)!
                                try await supabase.auth.signInWithOAuth(
                                    provider: .google,
                                    redirectTo: redirect,
                                    scopes: "openid email profile"
                                )
                            } catch {
                                await showErrorToast("Google sign-in failed. Please try again.")
                            }
                        }
                    }) {
                        Image("google_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .padding(8)
                            .background(Circle().fill(Color.white))
                    }
                    .frame(width: 44, height: 44)

                    // Apple Sign In (now uses same OAuth flow)
                    Button(action: {
                        emailFocused = false
                        Task {
                            do {
                                let redirect = URL(string: AppConfig.redirectURLString)!
                                try await supabase.auth.signInWithOAuth(
                                    provider: .apple,
                                    redirectTo: redirect,
                                    scopes: "name email"
                                )
                            } catch {
                                await showErrorToast("Apple sign-in failed. Please try again.")
                            }
                        }
                    }) {
                        Image("apple_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .padding(8)
                            .background(Circle().fill(Color.white))
                    }
                    .frame(width: 44, height: 44)
                }
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
                    Image(systemName: isErrorToast ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
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
                        .fill(isErrorToast ? Color.yellow.opacity(0.9) : Color.green.opacity(0.9))
                )
                .padding(.top, 40)
                .padding(.horizontal, 24)
                .transition(.move(edge: .top).combined(with: .opacity))
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 4)
                .ignoresSafeArea(.keyboard)
            }
        }
    }

    // MARK: - Toast helpers
    @MainActor
    private func showErrorToast(_ message: String) {
        toastMessage = message
        isErrorToast = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.easeOut(duration: 0.25)) { showToast = false }
        }
    }

    @MainActor
    private func showSuccessToast(_ message: String) {
        toastMessage = message
        isErrorToast = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.easeOut(duration: 0.25)) { showToast = false }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

