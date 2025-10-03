//
//  OnboardingView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI
import Supabase
import UIKit

struct ProfileUpdate: Encodable {
    let currency: String
    let onboarding_complete: Bool
}

private struct OnboardProgressBar: View {
    let progress: CGFloat
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

struct OnboardingView: View {
    private enum Step { case welcome, tutorial1, tutorial2, challenges, socialProof, goals, currency }

    @State private var step: Step = .welcome
    @State private var selectedCurrency: String = "USD"
    @State private var submitting = false

    @State private var isVisible = false
    @State private var isAnimating = false
    private let fadeDuration = 0.25

    @State private var selectedGoalIDs: Set<String> = []
    @State private var selectedChallengeIDs: Set<String> = []

    @State private var reviewPage: Int = 0
    @State private var currencyIndex: Int = 0
    @State private var showTapHint = false

    @EnvironmentObject var session: SessionStore
    var onComplete: () -> Void

    private let currencies = [
        "USD","EUR","GBP","JPY","AUD",
        "CAD","CHF","CNY","SEK","NZD",
        "MXN","SGD","HKD","NOK","KRW",
        "TRY","INR","RUB","BRL","ZAR"
    ]

    private var progressValue: CGFloat {
        switch step {
        case .welcome:     return 1.0/7.0
        case .tutorial1:   return 2.0/7.0
        case .tutorial2:   return 3.0/7.0
        case .challenges:  return 4.0/7.0
        case .socialProof: return 5.0/7.0
        case .goals:       return 6.0/7.0
        case .currency:    return 1.0
        }
    }

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

    @MainActor
    private func saveAndFinish() async {
        submitting = true
        do {
            let client  = SupabaseManager.shared.client
            let session = try await client.auth.session
            let userId  = session.user.id
            let update  = ProfileUpdate(currency: selectedCurrency, onboarding_complete: true)

            _ = try await client
                .from("profiles")
                .update(update)
                .eq("user_id", value: userId)
                .execute()

            submitting = false
            onComplete()
        } catch {
            submitting = false
        }
    }

    private func toggleGoal(_ id: String) {
        if selectedGoalIDs.contains(id) { selectedGoalIDs.remove(id) }
        else { selectedGoalIDs.insert(id) }
    }

    private func toggleChallenge(_ id: String) {
        if selectedChallengeIDs.contains(id) { selectedChallengeIDs.remove(id) }
        else { selectedChallengeIDs.insert(id) }
    }

    private func scheduleTapHint() {
        showTapHint = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if step == .welcome {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showTapHint = true
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardProgressBar(progress: progressValue)
                .padding(.horizontal)
                .padding(.top, 8)

            Group {
                switch step {
                case .welcome:
                    VStack {
                        Spacer(minLength: 12)
                        VStack(spacing: 12) {
                            Image("ghostbill_logo_transparent")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            Text("Welcome to Ghostbill 👋")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Your journey to stress-free finances begin here.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 240)
                                .padding(.top, 2)
                            if showTapHint {
                                Text("Tap to continue")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .transition(.opacity)
                                    .padding(.top, 8)
                            }
                        }
                        .offset(y: -16)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.prepare()
                        generator.impactOccurred()
                        crossfade { step = .tutorial1 }
                    }
                    .opacity(isVisible ? 1 : 0)

                case .tutorial1:
                    VStack {
                        Spacer(minLength: 12)
                        TutorialSlide()
                        Spacer()
                        HStack(spacing: 12) {
                            Button("Back") {
                                crossfade { step = .welcome }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isAnimating)

                            Button("Continue") {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.prepare()
                                generator.impactOccurred()
                                crossfade { step = .tutorial2 }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentColor)
                            .disabled(isAnimating)
                        }
                        .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(isVisible ? 1 : 0)

                case .tutorial2:
                    VStack {
                        Spacer(minLength: 12)
                        TutorialRecordSlide()
                        Spacer()
                        HStack(spacing: 12) {
                            Button("Back") {
                                crossfade { step = .tutorial1 }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isAnimating)

                            Button("Continue") {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.prepare()
                                generator.impactOccurred()
                                crossfade { step = .challenges }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentColor)
                            .disabled(isAnimating)
                        }
                        .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(isVisible ? 1 : 0)

                case .challenges:
                    VStack(spacing: 16) {
                        Spacer(minLength: 12)
                        Text("What financial challenges can we help you solve?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)

                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ChallengesList(items: CHALLENGES, selected: $selectedChallengeIDs, toggle: toggleChallenge)
                            }
                            .padding(.vertical, 4)
                        }

                        HStack(spacing: 12) {
                            Button("Back") {
                                crossfade { step = .tutorial2 }
                            }
                            .buttonStyle(.bordered)
                            Button("Continue") {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.prepare()
                                generator.impactOccurred()
                                crossfade { step = .socialProof }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentColor)
                            .disabled(isAnimating)
                        }
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal)
                    .opacity(isVisible ? 1 : 0)

                case .socialProof:
                    VStack(spacing: 16) {
                        Spacer(minLength: 8)

                        Image("ghostbill_logo_transparent")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        Text("Join 1500+ users building better spending habits.")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)

                        HStack(alignment: .center, spacing: 16) {
                            Image("left")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 80)
                                .accessibilityHidden(true)

                            VStack(spacing: 6) {
                                Text("1500+")
                                    .font(.system(size: 36, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .allowsTightening(true)
                                Text("active users")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                StarsRow()
                            }
                            .frame(minWidth: 0, maxWidth: .infinity)

                            Image("right")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 80)
                                .accessibilityHidden(true)
                        }
                        .padding(.top, 2)

                        Text("GhostBill transforms how people understand and manage their spending.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text("We help you save money each month so you can reach your goals.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                            .padding(.horizontal)

                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                                TabView(selection: $reviewPage) {
                                    ForEach(REVIEWS.indices, id: \.self) { idx in
                                        ReviewCard(review: REVIEWS[idx])
                                            .tag(idx)
                                            .padding(.horizontal)
                                    }
                                }
                                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                            .padding(.horizontal)

                            HStack(spacing: 6) {
                                ForEach(0..<REVIEWS.count, id: \.self) { i in
                                    Circle()
                                        .fill(i == reviewPage ? Color.primary.opacity(0.9) : Color.secondary.opacity(0.4))
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding(.top, 2)
                        }

                        Spacer()

                        HStack(spacing: 12) {
                            Button("Back") {
                                crossfade { step = .challenges }
                            }
                            .buttonStyle(.bordered)

                            Button("Continue") {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.prepare()
                                generator.impactOccurred()
                                crossfade { step = .goals }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentColor)
                        }
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal)
                    .opacity(isVisible ? 1 : 0)

                case .goals:
                    VStack(spacing: 24) {
                        Spacer(minLength: 20)
                        Text("What are your goals?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top, 12)
                        VStack(spacing: 12) {
                            ForEach(GOALS) { goal in
                                Button { toggleGoal(goal.id) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: goal.symbol)
                                            .imageScale(.large)
                                            .foregroundColor(goal.color)
                                            .frame(width: 28)
                                        Text(goal.title)
                                            .font(.headline)
                                        Spacer()
                                        Image(systemName: selectedGoalIDs.contains(goal.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedGoalIDs.contains(goal.id) ? .accentColor : Color(.tertiaryLabel))
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.secondary.opacity(0.12))
                                    .cornerRadius(12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Spacer()
                        HStack(spacing: 12) {
                            Button("Back") {
                                crossfade({ step = .socialProof })
                            }
                            .buttonStyle(.bordered)
                            Button("Continue") {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.prepare()
                                generator.impactOccurred()
                                crossfade { step = .currency }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentColor)
                            .disabled(submitting)
                        }
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal)
                    .opacity(isVisible ? 1 : 0)

                case .currency:
                    VStack {
                        Spacer()
                        CurrencySelect(currencies: currencies, index: $currencyIndex)
                        Spacer()
                        HStack(spacing: 12) {
                            Button("Back") {
                                crossfade { step = .goals }
                            }
                            .buttonStyle(.bordered)
                            Button("Finish") {
                                selectedCurrency = currencies[currencyIndex]
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.prepare()
                                generator.impactOccurred()
                                Task { await saveAndFinish() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentColor)
                            .disabled(submitting || isAnimating)
                        }
                        .padding(.bottom, 24)
                    }
                    .opacity(isVisible ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            isVisible = false
            withAnimation(.easeInOut(duration: fadeDuration)) { isVisible = true }
            if let i = currencies.firstIndex(of: selectedCurrency) {
                currencyIndex = i
            } else {
                selectedCurrency = currencies.first ?? "USD"
                currencyIndex = 0
            }
            scheduleTapHint()
        }
        .onChange(of: step) { newStep in
            if newStep == .welcome {
                scheduleTapHint()
            } else {
                showTapHint = false
            }
        }
    }
}

