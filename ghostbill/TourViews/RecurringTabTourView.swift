//
//  RecurringTabTourView.swift
//  ghostbill
//

import SwiftUI
import Supabase

struct RecurringTabTourView: View {
    var onDismiss: () -> Void = {}

    // Local step state
    @State private var stepIndex: Int = 0
    @State private var isFinishing = false

    private struct Step: Identifiable {
        let id = UUID()
        let title: String
        let body: String
        let primary: String
        let secondary: String?
    }

    private let steps: [Step] = [
        Step(
            title: "Recurring bills & subscriptions",
            body: "Track repeating bills like rent and Netflix.",
            primary: "Learn how",
            secondary: "Skip"
        ),
        Step(
            title: "Add a recurring payment",
            body: "Tap the + in the top-right to add one.",
            primary: "Next",
            secondary: "Back"
        ),
        Step(
            title: "See them on the calendar",
            body: "Payment days are marked with a green circle on your calendar.",
            primary: "Close",
            secondary: "Back"
        )
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { if stepIndex == 0 { finishTour() } }
                .allowsHitTesting(stepIndex != 1)

            GeometryReader { geo in
                switch stepIndex {
                case 0:
                    VStack {
                        Spacer(minLength: 0)
                        card
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)

                case 1:
                    ZStack(alignment: .topTrailing) {
                        VStack {
                            card
                                .padding(.top, geo.safeAreaInsets.top + 76)
                                .padding(.horizontal, 24)
                            Spacer(minLength: 0)
                        }

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 6)
                            .padding(.top, geo.safeAreaInsets.top + 10)
                            .padding(.trailing, 36)
                            .allowsHitTesting(false)
                    }

                default:
                    VStack {
                        Spacer(minLength: 0)
                        card
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: stepIndex)
    }

    private var card: some View {
        VStack(spacing: 16) {
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

            HStack(spacing: 8) {
                if stepIndex == 2 {
                    Image(systemName: "calendar")
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

            if stepIndex == 2 {
                Circle()
                    .fill(Color.green)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.85), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                    .frame(maxWidth: .infinity)
                    .padding(.top, -2)
            }

            HStack(spacing: 10) {
                if let secondary = steps[stepIndex].secondary {
                    Button {
                        if stepIndex == 0 {
                            finishTour()
                        } else {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                stepIndex = max(0, stepIndex - 1)
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
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.indigo.opacity(0.95),
                            Color.blue.opacity(0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.7),
                            Color.mint.opacity(0.45)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 28, x: 0, y: 14)
    }

    private func finishTour() {
        guard !isFinishing else { return }
        isFinishing = true

        Task {
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                let userId = session.user.id
                try await ProfilesService.shared.setSeenRecurringTour(userId: userId, seen: true)
            } catch {
                print("⚠️ Failed to persist seen_recurring_tour: \(error.localizedDescription)")
            }
            await MainActor.run {
                onDismiss()
                isFinishing = false
            }
        }
    }
}

