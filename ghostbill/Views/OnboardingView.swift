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

// MARK: - Subtle thin progress bar for onboarding
private struct OnboardProgressBar: View {
    let progress: CGFloat // 0...1
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(Color.accentColor.opacity(0.65))
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
            }
        }
        .frame(height: 3)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

// MARK: - Goals data + rows (inlined)
private struct Goal: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let color: Color
}

private let GOALS: [Goal] = [
    .init(id: "trackAllSpending",   title: "Track every purchase",               symbol: "list.bullet.rectangle", color: .blue),
    .init(id: "understandPatterns", title: "Understand my spending patterns",    symbol: "chart.line.uptrend.xyaxis", color: .green),
    .init(id: "buildBetterHabits",  title: "Build smarter money habits",         symbol: "hand.thumbsup", color: .orange),
    .init(id: "growSavings",        title: "Grow my savings",                    symbol: "banknote", color: .mint),
    .init(id: "manageSubscriptions",title: "Keep subscriptions under control",   symbol: "creditcard", color: .purple),
    .init(id: "neverMissBills",     title: "Never miss a bill",                  symbol: "bell.badge", color: .red)
]

private struct GoalRow: View {
    let goal: Goal
    let isSelected: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: goal.symbol)
                .imageScale(.large)
                .foregroundColor(goal.color)
                .frame(width: 28)

            Text(goal.title)
                .font(.headline)

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : Color(.tertiaryLabel))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.12))
        .cornerRadius(12)
        .contentShape(Rectangle())
    }
}

private struct GoalsList: View {
    let goals: [Goal]
    @Binding var selectedIDs: Set<String>
    var toggle: (String) -> Void
    var body: some View {
        VStack(spacing: 12) {
            ForEach(goals) { goal in
                Button { toggle(goal.id) } label: {
                    GoalRow(goal: goal, isSelected: selectedIDs.contains(goal.id))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Main Onboarding (3 slides, single fade system)
struct OnboardingView: View {
    private enum Step { case welcome, currency, goals }

    @State private var step: Step = .welcome
    @State private var selectedCurrency: String = "USD"
    @State private var submitting = false

    // Fade/crossfade state shared by all slides
    @State private var isVisible = false
    @State private var isAnimating = false
    private let fadeDuration = 0.25

    // Goals UI state (not persisted by design)
    @State private var selectedGoalIDs: Set<String> = []

    @EnvironmentObject var session: SessionStore
    var onComplete: () -> Void

    private let currencies = [
        "USD","EUR","GBP","JPY","AUD",
        "CAD","CHF","CNY","SEK","NZD",
        "MXN","SGD","HKD","NOK","KRW",
        "TRY","INR","RUB","BRL","ZAR"
    ]

    // progress mapping
    private var progressValue: CGFloat {
        switch step {
        case .welcome:  return 1.0/3.0
        case .currency: return 2.0/3.0
        case .goals:    return 1.0
        }
    }

    // Crossfade helper (fade out -> swap -> fade in)
    private func crossfade(_ change: @escaping () -> Void, then completion: (() -> Void)? = nil) {
        guard !isAnimating else { return }
        isAnimating = true
        withAnimation(.easeInOut(duration: fadeDuration)) { isVisible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration) {
            change()
            withAnimation(.easeInOut(duration: fadeDuration)) { isVisible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration) {
                isAnimating = false
                completion?()
            }
        }
    }

    // Supabase save
    private func saveAndFinish() async {
        submitting = true
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id
            let update = ProfileUpdate(currency: selectedCurrency, onboarding_complete: true)

            _ = try await SupabaseManager.shared.client
                .from("profiles")
                .update(update)
                .eq("user_id", value: userId)
                .execute()

            submitting = false
            // No fade on finish — just complete
            onComplete()
        } catch {
            submitting = false
        }
    }

    // Goals selection
    private func toggleGoal(_ id: String) {
        if selectedGoalIDs.contains(id) { selectedGoalIDs.remove(id) }
        else { selectedGoalIDs.insert(id) }
    }

    var body: some View {
        // No NavigationStack — we keep everything local to unify transitions
        VStack(spacing: 0) {
            // Reserve space for progress at top, so content never overlaps
            OnboardProgressBar(progress: progressValue)
                .padding(.horizontal)
                .padding(.top, 8)

            Group {
                switch step {
                case .welcome:
                    // MARK: Slide 1 — Welcome
                    VStack {
                        Spacer(minLength: 12)

                        VStack(spacing: 12) {
                            Image("ghostbill_logo_transparent")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 20))

                            Text("Welcome to Ghostbill")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Our mission is to help you take control of your money.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 240)
                                .padding(.top, 2)
                        }
                        .offset(y: -16) // lift the block a bit

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { crossfade { step = .currency } }
                    .opacity(isVisible ? 1 : 0)
                    .safeAreaInset(edge: .bottom) {
                        Text("Tap to continue")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                            .padding(.bottom, 20)
                            .frame(maxWidth: .infinity)
                            .background(.clear)
                    }

                case .currency:
                    // MARK: Slide 2 — Currency
                    VStack {
                        Spacer()

                        VStack(spacing: 20) {
                            Text("Choose your currency")
                                .font(.title3)
                                .fontWeight(.semibold)

                            Picker("Currency", selection: $selectedCurrency) {
                                ForEach(currencies, id: \.self) { currency in
                                    Text(currency).tag(currency)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 140)
                        }

                        Spacer()

                        HStack(spacing: 12) {
                            Button("Back") { crossfade { step = .welcome } }
                                .buttonStyle(.bordered)

                            Button("Continue") { crossfade { step = .goals } }
                                .buttonStyle(.borderedProminent)
                                .tint(.accentColor)
                                .disabled(submitting || isAnimating)
                        }
                        .padding(.bottom, 24)
                    }
                    .opacity(isVisible ? 1 : 0)

                case .goals:
                    // MARK: Slide 3 — Goals
                    VStack(spacing: 24) {
                        Spacer(minLength: 20)
                        Text("What are your goals?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top, 12)

                        GoalsList(goals: GOALS, selectedIDs: $selectedGoalIDs, toggle: toggleGoal)

                        Spacer()

                        HStack(spacing: 12) {
                            Button("Back") { crossfade { step = .currency } }
                                .buttonStyle(.bordered)

                            Button("Finish") {
                                // ✅ No fade here — close immediately after saving
                                Task { await saveAndFinish() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentColor)
                            .disabled(submitting)
                        }
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal)
                    .opacity(isVisible ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            // fade in initial slide
            isVisible = false
            withAnimation(.easeInOut(duration: fadeDuration)) { isVisible = true }
        }
    }
}

