//
//  CategoryBreakdownView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-16.
//

import SwiftUI
import Supabase

struct CategoryBreakdownView: View {
    // Palette
    private let bg        = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let cardBG    = Color(red: 0.14, green: 0.14, blue: 0.17)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let stroke    = Color.white.opacity(0.06)

    // Data
    @State private var items: [(category: ExpenseCategory, count: Int)] = []
    @State private var totalCount: Int = 0
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            Group {
                if let errorText {
                    VStack(spacing: 8) {
                        Text("Couldn't load categories")
                            .foregroundColor(textLight)
                            .font(.headline)
                        Text(errorText)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                    .padding(.horizontal, 16)
                } else if isLoading && items.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(0..<6, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 56)
                                .redacted(reason: .placeholder)
                        }
                    }
                    .padding(.horizontal, 16)
                } else if items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 28))
                            .foregroundColor(textMuted.opacity(0.85))
                        Text("No category data yet")
                            .foregroundColor(textMuted)
                            .font(.subheadline)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(items.indices, id: \.self) { i in
                                let entry = items[i]
                                let pct = percentageString(for: entry.count, total: totalCount)

                                NavigationLink {
                                    ExpandedCategoryView(category: entry.category)
                                } label: {
                                    HStack(spacing: 12) {
                                        CategoryBadge(category: entry.category)

                                        Text(entry.category.title)
                                            .foregroundColor(textLight)
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.9)

                                        Spacer()

                                        Text(pct)
                                            .foregroundColor(textLight)
                                            .font(.subheadline.weight(.semibold))
                                            .accessibilityLabel("\(pct) of transactions")
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18)
                                            .fill(cardBG)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .stroke(stroke, lineWidth: 1)
                                            )
                                    )
                                }
                                // Lighten the card while pressed
                                .buttonStyle(PressableCardStyle(base: cardBG))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .navigationTitle("Category Breakdown")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
    }

    // MARK: - Data

    private func loadData() async {
        isLoading = true
        errorText = nil
        do {
            let session = try? await SupabaseManager.shared.client.auth.session
            guard let uid = session?.user.id else {
                isLoading = false
                errorText = "Not signed in."
                return
            }

            // Fetch all categories by count (same source as the donut)
            let top = try await CategoryService.shared.getTopExpenseCategoriesByCountAllTime(
                userId: uid,
                limit: nil
            )

            let filtered = top.filter { $0.count > 0 }
            let total = max(1, filtered.reduce(0) { $0 + $1.count })

            // Sort descending by count
            let sorted: [(ExpenseCategory, Int)] = filtered
                .sorted(by: { $0.count > $1.count })
                .map { ($0.category, $0.count) }

            await MainActor.run {
                self.items = sorted
                self.totalCount = total
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.items = []
                self.totalCount = 0
                self.isLoading = false
                self.errorText = (error as NSError).localizedDescription
            }
        }
    }

    // MARK: - Helpers

    private func percentageString(for count: Int, total: Int) -> String {
        guard total > 0 else { return "0%" }
        let pct = Int(round((Double(count) / Double(total)) * 100.0))
        return "\(pct)%"
    }
}

/// A subtle press effect that lightens the card background while the row is pressed.
private struct PressableCardStyle: ButtonStyle {
    let base: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(base.opacity(configuration.isPressed ? 0.9 : 1.0))
            )
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

