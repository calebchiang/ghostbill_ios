//
//  SavingsTabTourView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-18.
//

import SwiftUI
import Supabase

struct SavingsTabTourView: View {
    var onDismiss: () -> Void = {}

    // Local step state
    @State private var stepIndex: Int = 0
    @State private var isFinishing: Bool = false

    private struct Step: Identifiable {
        let id = UUID()
        let title: String
        let body: String
        let primary: String
        let secondary: String?
    }

    private let steps: [Step] = [
        Step(
            title: "Monthly savings",
            body: "See how much you save each month.",
            primary: "Get started",
            secondary: "Skip"
        ),
        Step(
            title: "Report your income",
            body: "Begin by reporting this month’s income. Your savings are calculated as income minus spending.",
            primary: "Close",
            secondary: "Back"
        )
    ]

    var body: some View {
        ZStack {
            // Dim background — allow taps through on step 2 so the Add Income button is tappable.
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .allowsHitTesting(stepIndex != 1)

            GeometryReader { geo in
                if stepIndex == 0 {
                    // STEP 1: centered card
                    VStack {
                        Spacer(minLength: 0)
                        card
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                } else {
                    // STEP 2: arrow above, card lower
                    ZStack {
                        // Card lower on screen
                        VStack {
                            card
                                .padding(.top, geo.safeAreaInsets.top + 220)
                                .padding(.horizontal, 24)
                                .zIndex(0)
                            Spacer(minLength: 0)
                        }

                        // Arrow ABOVE the card (about 40pt above)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, geo.safeAreaInsets.top + 180)
                            .allowsHitTesting(false)
                            .zIndex(1)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: stepIndex)
    }

    // MARK: - Card (matches other tours)
    private var card: some View {
        VStack(spacing: 16) {
            // Progress dots (2 steps)
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

            // Title (show a savings icon on step 1 only)
            HStack(spacing: 8) {
                if stepIndex == 0 {
                    Image(systemName: "banknote")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white)
                        .accessibilityHidden(true)
                }

                Text(steps[stepIndex].title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)

            Text(steps[stepIndex].body)
                .font(.callout)
                .foregroundColor(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                if let secondary = steps[stepIndex].secondary {
                    Button {
                        if stepIndex == 0 {
                            // Skip on step 1 => mark seen + dismiss
                            finishTour()
                        } else {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                stepIndex = 0
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
                    if stepIndex == 0 {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            stepIndex = 1
                        }
                    } else {
                        // Close on step 2 => mark seen + dismiss
                        finishTour()
                    }
                } label: {
                    Text(steps[stepIndex].primary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
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
            Color(red: 0.34, green: 0.25, blue: 0.70) // same solid purple as other tours
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 28, x: 0, y: 14)
    }

    // MARK: - Persist + dismiss
    private func finishTour() {
        guard !isFinishing else { return }
        isFinishing = true

        Task {
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                let userId = session.user.id
                try await ProfilesService.shared.setSeenSavingsTour(userId: userId, seen: true)
            } catch {
                print("⚠️ Failed to persist seen_savings_tour: \(error.localizedDescription)")
            }
            await MainActor.run {
                onDismiss()
                isFinishing = false
            }
        }
    }
}

