//
//  Overview.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI
import Supabase
import UIKit

struct SpookieStatusPayload {
    let title: String
    let message: String
}

struct CategorySlice: Identifiable {
    let id = UUID()
    let category: String
    let total: Double
}

struct Overview: View {
    let transactions: [DBTransaction]
    let onStatusTap: (SpookieStatusPayload) -> Void

    @State private var currencySymbol: String = "$"
    @State private var statusText: String?
    @State private var statusIconName: String?
    @State private var statusLabel: String?
    @State private var statusLabelColor: Color = .green
    @State private var statusProgress: Double = 0
    @State private var statusTitleOverride: String? = nil

    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)

    var body: some View {
        let monthName = formattedMonthTitle()
        let slices = categorySlicesForCurrentMonth()
        let total = slices.reduce(0) { $0 + $1.total }

        let colors: [Color] = slices.map { colorForCategoryString($0.category) }

        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                if let statusLabel, let statusIconName, let _ = statusText {
                    HStack {
                        Spacer(minLength: 0)
                        HStack(spacing: 8) {
                            Image(statusIconName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 38, height: 38)
                                .accessibilityHidden(true)

                            Text("Health:")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(textMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Text(statusLabel)
                                .font(.footnote.weight(.bold))
                                .foregroundColor(statusLabelColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Rectangle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 1, height: 12)
                                .padding(.horizontal, 2)

                            HealthBar(progress: statusProgress)
                                .frame(width: 72, height: 8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let generator = UIImpactFeedbackGenerator(style: .soft)
                            generator.prepare()
                            generator.impactOccurred(intensity: 0.8)
                            let payload = SpookieStatusPayload(
                                title: statusPopupTitle(),
                                message: statusText ?? ""
                            )
                            onStatusTap(payload)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 30)
                }

                ZStack {
                    DonutChart(
                        slices: slices.map { ($0.category, $0.total) },
                        colors: colors,
                        thickness: 30
                    )
                    .frame(height: 220)

                    VStack(spacing: 4) {
                        (
                            Text(monthName).fontWeight(.bold)
                            + Text(" spend")
                        )
                        .font(.footnote)
                        .foregroundColor(textMuted)
                        Text(formatAmount(total))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(textLight)
                    }
                }
                .padding(.bottom, 16)

                if !slices.isEmpty {
                    let columns = [GridItem(.flexible(), spacing: 12),
                                   GridItem(.flexible(), spacing: 12)]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                        ForEach(Array(zip(slices.indices, slices)), id: \.0) { (idx, slice) in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(colors[idx])
                                    .frame(width: 10, height: 10)
                                Text(slice.category)
                                    .font(.footnote)
                                    .foregroundColor(textMuted)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .background(bg.opacity(0.001))
            .task { await loadCurrencySymbol() }
            .task { await loadSpendingStatus() }
            .onChange(of: transactions) { _ in
                Task { await loadSpendingStatus() }
            }
        }
    }

    private func statusPopupTitle() -> String {
        if let override = statusTitleOverride { return override }
        switch statusLabel {
        case "Happy":
            return "Spookie is happy and healthy!"
        case "Nervous":
            return "Spookie is getting nervous..."
        case "Critical":
            return "Help! Spookie is on life support."
        default:
            return "Spending update"
        }
    }

    private func loadCurrencySymbol() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id
            if let code = try await ProfilesService.shared.getUserCurrency(userId: userId),
               let sym = CurrencySymbols.symbols[code] {
                currencySymbol = sym
            } else {
                currencySymbol = "$"
            }
        } catch {
            currencySymbol = "$"
        }
    }

    private func loadSpendingStatus(monthsBack: Int = 12) async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            guard let uid = session.user.id as UUID? else { return }

            let points = try await CategoryService.shared.getSpendingOverTime(
                userId: uid,
                monthsBack: monthsBack
            )

            let nonZeroCount = points.filter { $0.total > 0 }.count

            if nonZeroCount < 2 {
                await MainActor.run {
                    self.statusLabel        = "Happy"
                    self.statusLabelColor   = .green
                    self.statusIconName     = "happy_ghost"
                    self.statusProgress     = 1.0
                    self.statusTitleOverride = "Spookie is feeling good."
                    self.statusText         = "Keep recording transactions to keep Spookie happy!"
                }
                return
            } else {
                await MainActor.run { self.statusTitleOverride = nil }
            }

            let result = spendingStatus(points: points)
            await MainActor.run {
                self.statusText         = result.detailText
                self.statusIconName     = result.iconName
                self.statusLabel        = result.label
                self.statusLabelColor   = result.labelColor
                self.statusProgress     = result.progress
                self.statusTitleOverride = nil
            }
        } catch {
            await MainActor.run {
                self.statusLabel        = "Happy"
                self.statusLabelColor   = .green
                self.statusIconName     = "happy_ghost"
                self.statusProgress     = 1.0
                self.statusTitleOverride = "Spookie is feeling good!"
                self.statusText         = "Keep recording transactions to keep Spookie happy!"
            }
        }
    }

    private func spendingStatus(points: [SpendingPoint]) -> (label: String, labelColor: Color, iconName: String, detailText: String, progress: Double) {
        let now = Date()
        let cal = Calendar.current
        let currentMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!

        guard let currentPoint = points.last, currentPoint.monthStart == currentMonthStart else {
            return ("", .green, "happy_ghost", "", 0)
        }

        let history = points.dropLast()
        let nonZeroHistory = history.filter { $0.total > 0 }
        let historyTotals = nonZeroHistory.map { $0.total }

        guard !historyTotals.isEmpty else {
            return ("", .green, "happy_ghost", "", 0)
        }

        let avg = historyTotals.reduce(0, +) / Double(historyTotals.count)
        guard avg > 0 else {
            return ("", .green, "happy_ghost", "", 0)
        }

        let current = currentPoint.total
        let delta = (current - avg) / avg
        let percent = Int(round(abs(delta) * 100))
        let percentStr = "\(percent)%"

        if delta <= -0.05 {
            return (
                label: "Happy",
                labelColor: .green,
                iconName: "happy_ghost",
                detailText: "You’re spending \(percentStr) less than usual. Keep it up!",
                progress: 1.0
            )
        } else if delta < 0 {
            return (
                label: "Happy",
                labelColor: .green,
                iconName: "happy_ghost",
                detailText: "You’re spending \(percentStr) less than usual. Nice pace.",
                progress: 1.0
            )
        } else if delta == 0 {
            return (
                label: "Happy",
                labelColor: .green,
                iconName: "happy_ghost",
                detailText: "You’re right on your usual spending.",
                progress: 1.0
            )
        } else if delta > 0 && delta < 0.15 {
            return (
                label: "Nervous",
                labelColor: .yellow,
                iconName: "nervous_ghost",
                detailText: "You’re spending \(percentStr) more than usual. Slightly above average.",
                progress: 2.0/3.0
            )
        } else {
            return (
                label: "Critical",
                labelColor: .red,
                iconName: "dead_ghost",
                detailText: "You’re spending \(percentStr) more than usual. Slow down!",
                progress: 0.10
            )
        }
    }

    private func categorySlicesForCurrentMonth() -> [CategorySlice] {
        let cal = Calendar.current
        let now = Date()
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let endOfMonth = cal.date(byAdding: .month, value: 1, to: startOfMonth)!

        let monthTxs = transactions.filter { tx in
            tx.date >= startOfMonth && tx.date < endOfMonth && tx.amount < 0
        }

        var buckets: [String: Double] = [:]
        for tx in monthTxs {
            let key = (tx.category?.trimmingCharacters(in: .whitespacesAndNewlines))
                .flatMap { $0.isEmpty ? nil : $0 } ?? "Other"
            buckets[key, default: 0] += abs(tx.amount)
        }

        return buckets
            .map { CategorySlice(category: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    private func colorForCategoryString(_ raw: String) -> Color {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let cat = ExpenseCategory(rawValue: key) {
            return cat.tint
        }
        switch key {
        case "food & drink", "restaurant", "food":
            return ExpenseCategory.dining.tint
        case "grocery", "supermarket":
            return ExpenseCategory.groceries.tint
        case "gas", "petrol":
            return ExpenseCategory.fuel.tint
        case "transportation":
            return ExpenseCategory.transport.tint
        case "rent", "mortgage":
            return ExpenseCategory.housing.tint
        case "bills", "phone", "internet", "power", "electricity":
            return ExpenseCategory.utilities.tint
        default:
            return ExpenseCategory.other.tint
        }
    }

    private func formattedMonthTitle() -> String {
        let f = DateFormatter()
        f.dateFormat = "LLLL"
        return f.string(from: Date())
    }

    private func formatAmount(_ value: Double) -> String {
        "\(currencySymbol)\(String(format: "%.2f", value))"
    }
}

private struct HealthBar: View {
    let progress: Double

    private let bgStroke = Color.white.opacity(0.20)
    private let trackFill = Color.white.opacity(0.15)
    private let mainFill  = Color.white.opacity(0.85)

    var body: some View {
        let filled = min(max(progress, 0), 1)

        GeometryReader { geo in
            let h = geo.size.height
            let barH = max(h * 0.58, 6)
            let barCorner = barH / 2
            let circleD = h
            let barW = max(geo.size.width - circleD - 6, 10)
            let xStart = circleD + 6

            ZStack(alignment: .leading) {
                ZStack {
                    Circle()
                        .fill(trackFill)
                    Circle()
                        .stroke(bgStroke, lineWidth: 2)
                    Image(systemName: "heart.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(circleD * 0.22)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 0)
                }
                .frame(width: circleD, height: circleD)

                RoundedRectangle(cornerRadius: barCorner)
                    .fill(trackFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: barCorner)
                            .stroke(bgStroke, lineWidth: 1)
                    )
                    .frame(width: barW, height: barH)
                    .position(x: xStart + barW / 2, y: h / 2)

                RoundedRectangle(cornerRadius: barCorner)
                    .fill(mainFill)
                    .frame(width: barW * filled, height: barH)
                    .position(x: xStart + (barW * filled) / 2, y: h / 2)
                    .mask(
                        RoundedRectangle(cornerRadius: barCorner)
                            .frame(width: barW, height: barH)
                            .position(x: xStart + barW / 2, y: h / 2)
                    )

                SegmentsOverlay()
                    .foregroundColor(Color.white.opacity(0.25))
                    .frame(width: barW * filled, height: barH)
                    .position(x: xStart + (barW * filled) / 2, y: h / 2)
                    .mask(
                        RoundedRectangle(cornerRadius: barCorner)
                            .frame(width: barW, height: barH)
                            .position(x: xStart + barW / 2, y: h / 2)
                    )
            }
        }
        .accessibilityLabel("Spending health")
    }
}

private struct SegmentsOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let step: CGFloat = max(8, h)
            let thickness: CGFloat = max(4, h * 0.6)

            Path { p in
                var x: CGFloat = -w
                while x < w * 2 {
                    p.addRoundedRect(
                        in: CGRect(x: x, y: (h - thickness) / 2, width: thickness, height: thickness),
                        cornerSize: CGSize(width: thickness/2, height: thickness/2)
                    )
                    x += step
                }
            }
            .rotationEffect(.degrees(-20))
        }
        .clipped()
    }
}

private struct DonutChart: View {
    let slices: [(label: String, value: Double)]
    let colors: [Color]
    let thickness: CGFloat

    var body: some View {
        GeometryReader { geo in
            let rect = geo.frame(in: .local)
            let size = min(rect.width, rect.height)
            let total = max(slices.reduce(0) { $0 + $1.value }, 0.0001)

            let segments: [(start: Angle, end: Angle, color: Color)] = slices.indices.map { idx in
                let startValue = slices.prefix(idx).reduce(0) { $0 + $1.value }
                let endValue = startValue + slices[idx].value
                let startDeg = -90 + (startValue / total) * 360
                let endDeg   = -90 + (endValue  / total) * 360
                return (start: .degrees(startDeg), end: .degrees(endDeg), color: colors[idx % colors.count])
            }

            ZStack {
                ForEach(Array(segments.enumerated()), id: \.0) { _, seg in
                    DonutArc(startAngle: seg.start, endAngle: seg.end)
                        .stroke(seg.color, style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
                        .frame(width: size, height: size)
                }
            }
            .frame(width: rect.width, height: rect.height)
        }
    }
}

private struct DonutArc: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        p.addArc(center: center,
                 radius: radius,
                 startAngle: startAngle,
                 endAngle: endAngle,
                 clockwise: false)
        return p
    }
}

