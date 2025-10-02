//
//  Challenges.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-30.
//

import SwiftUI

// MARK: - Model

struct Challenge: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
}

// MARK: - Data

let CHALLENGES: [Challenge] = [
    .init(
        id: "stressOpenBankApp",
        title: "Stress opening your bank app",
        subtitle: "Avoiding viewing your balance",
        symbol: "eye.slash"
    ),
    .init(
        id: "dontKnowWhereMoneyGoes",
        title: "Don’t know where money goes",
        subtitle: "Hard to see monthly patterns.",
        symbol: "questionmark.circle"
    ),
    .init(
        id: "cantTrackSubscriptions",
        title: "Hard to track subscriptions",
        subtitle: "Unclear what’s active,",
        symbol: "repeat"
    ),
    .init(
        id: "overdraftFees",
        title: "Overdrafts from forgotten bills",
        subtitle: "Late charges and surprise debits.",
        symbol: "exclamationmark.triangle"
    ),
    .init(
        id: "difficultySaving",
        title: "Saving is inconsistent",
        subtitle: "Tough to set money aside.",
        symbol: "banknote"
    ),
    .init(
        id: "cashSpendingSmallPurchases",
        title: "Small purchases add up",
        subtitle: "Coffee, snacks, rides.",
        symbol: "cart"
    ),
    .init(
        id: "paycheckToPaycheck",
        title: "Living paycheck to paycheck",
        subtitle: "Cash gets tight each month.",
        symbol: "calendar.badge.clock"
    )
]

// MARK: - Views

struct ChallengeCard: View {
    let challenge: Challenge
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Leading icon box
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.purple.opacity(0.15) : Color(.tertiarySystemFill))
                Image(systemName: challenge.symbol)
                    .imageScale(.large)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? .purple : .secondary)
            }
            .frame(width: 44, height: 44)

            // Title + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(challenge.title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(challenge.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.purple.opacity(0.35) : Color.clear, lineWidth: 2)
        )
        .shadow(color: isSelected ? Color.purple.opacity(0.25) : .clear, radius: 12, x: 0, y: 6)
        .contentShape(Rectangle())
    }
}

struct ChallengesList: View {
    let items: [Challenge]
    @Binding var selected: Set<String>
    var toggle: (String) -> Void

    var body: some View {
        ForEach(items) { item in
            Button {
                toggle(item.id)
            } label: {
                ChallengeCard(challenge: item, isSelected: selected.contains(item.id))
            }
            .buttonStyle(.plain)
        }
    }
}

