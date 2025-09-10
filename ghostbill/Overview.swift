//
//  Overview.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI

struct CategorySlice: Identifiable {
    let id = UUID()
    let category: String
    let total: Double
}

struct Overview: View {
    let transactions: [DBTransaction]

    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)

    private let palette: [Color] = [
        Color(red: 0.31, green: 0.27, blue: 0.90),
        Color(red: 0.15, green: 0.72, blue: 0.47),
        Color(red: 0.97, green: 0.64, blue: 0.14),
        Color(red: 0.93, green: 0.26, blue: 0.30),
        Color(red: 0.19, green: 0.60, blue: 0.93),
        Color(red: 0.75, green: 0.27, blue: 0.78),
        Color(red: 0.95, green: 0.77, blue: 0.06),
        Color(red: 0.31, green: 0.83, blue: 0.76),
        Color(red: 0.92, green: 0.47, blue: 0.63),
        Color(red: 0.54, green: 0.58, blue: 0.66)
    ]

    var body: some View {
        let monthName = formattedMonthTitle()
        let slices = categorySlicesForCurrentMonth()
        let total = slices.reduce(0) { $0 + $1.total }
        let colors: [Color] = slices.indices.map { palette[$0 % palette.count] }

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(monthName)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(textLight)
                    .padding(.bottom, 16)
                Spacer()
                
            }

            ZStack {
                DonutChart(
                    slices: slices.map { ($0.category, $0.total) },
                    colors: colors,
                    thickness: 30
                )
                .frame(height: 220)

                VStack(spacing: 4) {
                    Text("Total Spend")
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
            } else {
                Text("No spend yet this month")
                    .font(.footnote)
                    .foregroundColor(textMuted)
                    .padding(.bottom, 20)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .background(bg.opacity(0.001))
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
            let key = (tx.category?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Other"
            buckets[key, default: 0] += abs(tx.amount)
        }

        return buckets
            .map { CategorySlice(category: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    private func formattedMonthTitle() -> String {
        let f = DateFormatter()
        f.dateFormat = "LLLL"
        return f.string(from: Date())
    }

    private func formatAmount(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}

// MARK: - DonutChart (SwiftUI, no mutation inside ViewBuilder)

private struct DonutChart: View {
    let slices: [(label: String, value: Double)]
    let colors: [Color]
    let thickness: CGFloat

    var body: some View {
        GeometryReader { geo in
            let rect = geo.frame(in: .local)
            let size = min(rect.width, rect.height)
            let total = max(slices.reduce(0) { $0 + $1.value }, 0.0001)

            // Precompute angles to avoid mutation inside the ViewBuilder.
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

