//
//  HomeTabTourView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-17.
//

import SwiftUI
import Supabase

struct HomeTabTourView: View {
    // Parent can pass this to hide the overlay after we persist the flag.
    var onDismiss: () -> Void = {}

    // Local step state
    @State private var stepIndex: Int = 0
    @State private var isFinishing = false

    // Simple step model
    private struct Step: Identifiable {
        let id = UUID()
        let title: String
        let body: String
        let primary: String
        let secondary: String?
    }

    // Steps for the Home tab tour (keep the wording you provided)
    private let steps: [Step] = [
        Step(
            title: "Welcome to GhostBill 👋",
            body: "Let's start tracking your spending! Begin by recording a transaction.",
            primary: "Next",
            secondary: "Skip"
        ),
        Step(
            title: "Add an expense",
            body: "Quickly record an expense by scanning your receipt with the Scanner.",
            primary: "Close",
            secondary: "Back"
        )
    ]

    var body: some View {
        ZStack {
            // Dim background around the card
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                // Allow outside taps to close ONLY on step 1; on step 2 let taps pass through to the tab bar
                .onTapGesture { if stepIndex == 0 { finishTour() } }
                .allowsHitTesting(stepIndex == 0)

            GeometryReader { geo in
                ZStack {
                    if stepIndex == 0 {
                        // STEP 1: centered card
                        VStack {
                            Spacer(minLength: 0)
                            card
                                .transition(.move(edge: .top).combined(with: .opacity))
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 24)
                    } else {
                        // STEP 2: lower card + down arrow pointing to Scan icon (center bottom)
                        VStack(spacing: 10) {
                            card
                                .transition(.move(edge: .bottom).combined(with: .opacity))

                            // Down arrow pointing toward the center scan icon
                            Image(systemName: "arrow.down")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(radius: 6)
                                .allowsHitTesting(false)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        // Place closer to the custom tab bar & safe area (lower on screen)
                        .padding(.bottom, max(geo.safeAreaInsets.bottom + 100, 100))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: stepIndex)
    }

    // MARK: - Card content (shared between steps)

    private var card: some View {
        VStack(spacing: 16) {
            // Progress dots
            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { i in
                    Circle()
                        .frame(width: 6, height: 6)
                        .foregroundStyle(
                            LinearGradient(
                                colors: i == stepIndex
                                ? [
                                    Color(hue: 0.62, saturation: 0.45, brightness: 0.95),
                                    Color(hue: 0.59, saturation: 0.30, brightness: 1.00)
                                  ]
                                : [Color.white.opacity(0.35), Color.white.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(i == stepIndex ? 1 : 0.8)
                }
            }
            .padding(.top, 2)

            Text(steps[stepIndex].title)
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(steps[stepIndex].body)
                .font(.callout)
                .foregroundColor(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                if let secondary = steps[stepIndex].secondary {
                    Button {
                        if stepIndex == 0 {
                            // Skip: finish immediately & persist seen=true
                            finishTour()
                        } else {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                stepIndex = max(stepIndex - 1, 0)
                            }
                        }
                    } label: {
                        Text(secondary)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isFinishing)
                }

                Button {
                    if stepIndex < steps.count - 1 {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            stepIndex += 1
                        }
                    } else {
                        // Close on step 2: finish & persist seen=true
                        finishTour()
                    }
                } label: {
                    Text(steps[stepIndex].primary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.white) // solid, minimal button bg
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isFinishing)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            Color(red: 0.34, green: 0.25, blue: 0.70) // ← solid purple (no gradient)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1) // solid, subtle stroke
        )
        .shadow(color: Color.black.opacity(0.35), radius: 28, x: 0, y: 14)
    }

    // MARK: - Finish + persist

    private func finishTour() {
        guard !isFinishing else { return }
        isFinishing = true

        Task {
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                let userId = session.user.id
                try await ProfilesService.shared.setSeenHomeTour(userId: userId, seen: true)
            } catch {
                print("⚠️ Failed to persist seen_home_tour: \(error.localizedDescription)")
            }
            await MainActor.run {
                onDismiss()
                isFinishing = false
            }
        }
    }
}

