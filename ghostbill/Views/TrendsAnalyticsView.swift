//
//  TrendsAnalyticsView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-13.
//

import SwiftUI
import Supabase

struct TrendsAnalyticsView: View {
    // Palette
    private let cardBG    = Color(red: 0.14, green: 0.14, blue: 0.17)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let stroke    = Color.white.opacity(0.06)

    // Data
    @State private var slices: [TrendSlice] = []
    @State private var points: [SpendingPoint] = []
    @State private var isLoading = false
    @State private var errorText: String?

    // Interaction (line chart selection)
    @State private var selectedSpendingIndex: Int? = nil

    // Navigation
    @State private var showCategoryBreakdown = false

    // Derived
    private var totalSpend: Double {
        slices.reduce(0) { $0 + $1.total }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ===== Section 1: Top Categories (Donut) =====
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        showCategoryBreakdown = true
                    } label: {
                        HStack {
                            Text("Top Categories")
                                .font(.headline)
                                .foregroundColor(textLight)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(textMuted)
                                .font(.subheadline.weight(.semibold))
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if let errorText {
                        Text(errorText)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    } else if isLoading && slices.isEmpty {
                        VStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 220)
                                .redacted(reason: .placeholder)

                            LazyVGrid(
                                columns: [GridItem(.flexible(), spacing: 12),
                                          GridItem(.flexible(), spacing: 12)],
                                alignment: .leading, spacing: 8
                            ) {
                                ForEach(0..<6, id: \.self) { _ in
                                    HStack(spacing: 8) {
                                        Circle().fill(Color.white.opacity(0.10))
                                            .frame(width: 10, height: 10)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.white.opacity(0.06))
                                            .frame(width: 100, height: 10)
                                    }
                                    .redacted(reason: .placeholder)
                                }
                            }
                        }
                    } else if slices.isEmpty {
                        Text("No expense data found.")
                            .font(.subheadline)
                            .foregroundColor(textMuted)
                            .padding(.top, 2)
                    } else {
                        DonutChartView(slices: slices)
                            .frame(height: 240)
                            .overlay(
                                VStack(spacing: 2) {
                                    Text("$\(formatNumber(totalSpend))")
                                        .font(.title2.weight(.bold))
                                        .foregroundColor(textLight)
                                    Text("Total Spend")
                                        .font(.caption)
                                       .foregroundColor(textMuted)
                                }
                            )

                        // Legend
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 12),
                                      GridItem(.flexible(), spacing: 12)],
                            alignment: .leading, spacing: 8
                        ) {
                            ForEach(slices) { s in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(s.category.tint)
                                        .frame(width: 10, height: 10)
                                    Text("\(s.category.title) - \(percentage(for: s))%")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(textLight)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 20).fill(cardBG))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(stroke, lineWidth: 1))
                .background(
                    NavigationLink(
                        destination: CategoryBreakdownView(),
                        isActive: $showCategoryBreakdown
                    ) { EmptyView() }
                    .hidden()
                )

                // ===== Section 2: Spending Over Time (Line) =====
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Spending Over Time")
                            .font(.headline)
                            .foregroundColor(textLight)
                        Spacer()
                    }

                    let nonZeroPoints = points.filter { $0.total > 0 }

                    if isLoading && nonZeroPoints.isEmpty {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 220)
                            .redacted(reason: .placeholder)
                    } else if nonZeroPoints.isEmpty {
                        Text("No historical spending yet.")
                            .font(.subheadline)
                            .foregroundColor(textMuted)
                            .padding(.top, 2)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            LineChartSpendingMonthly(
                                points: nonZeroPoints.map { ($0.monthStart, $0.total) },
                                accent: Color(red: 0.58, green: 0.55, blue: 1.00),
                                selected: $selectedSpendingIndex
                            )
                            .frame(height: 220)

                            HStack(spacing: 0) {
                                ForEach(xLabels(for: nonZeroPoints), id: \.self) { lbl in
                                    Text(lbl)
                                        .font(.caption2)
                                        .foregroundColor(textMuted)
                                    Spacer(minLength: 0)
                                }
                            }

                            let avg: Double = {
                                let vals = nonZeroPoints.map { $0.total }
                                guard !vals.isEmpty else { return 0 }
                                return vals.reduce(0, +) / Double(vals.count)
                            }()

                            Divider().background(Color.white.opacity(0.08)).padding(.top, 4)

                            HStack {
                                Text("Average monthly spending")
                                    .font(.subheadline)
                                    .foregroundColor(textMuted)
                                Spacer()
                                Text("$\(formatNumber(avg))") 
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(textLight)
                                    .accessibilityLabel("Average monthly spending \(formatNumber(avg))")
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 20).fill(cardBG))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(stroke, lineWidth: 1))
            }
            .padding(.vertical, 10)
            .task { await loadData() }
        }
    }

    // MARK: - Helpers
    private func percentage(for slice: TrendSlice) -> Int {
        let total = max(1.0, slices.reduce(0) { $0 + $1.total })
        return Int(round((slice.total / total) * 100))
    }

    private func xLabels(for pts: [SpendingPoint]) -> [String] {
        guard !pts.isEmpty else { return [] }
        let f = DateFormatter()
        f.dateFormat = "MMM"
        let step = max(1, pts.count / 5)
        return stride(from: 0, to: pts.count, by: step).map { f.string(from: pts[$0].monthStart) }
    }

    private func formatNumber(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        nf.minimumFractionDigits = 0
        return nf.string(from: NSNumber(value: value)) ?? "\(Int(value))"
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

            async let topTask = CategoryService.shared.getTopExpenseCategoriesByAmountAllTime(
                userId: uid, limit: nil
            )
            async let overTimeTask = CategoryService.shared.getSpendingOverTime(
                userId: uid, monthsBack: 12
            )

            let (topAmounts, overTime) = try await (topTask, overTimeTask)

            let filtered = topAmounts.filter { $0.total > 0 }
            let mapped: [TrendSlice] = filtered.map {
                TrendSlice(category: $0.category, total: $0.total)
            }

            self.slices = mapped
            self.points = overTime
            self.isLoading = false
        } catch {
            self.slices = []
            self.points = []
            self.isLoading = false
            self.errorText = (error as NSError).localizedDescription
        }
    }
}

// MARK: - Donut renderer
fileprivate struct DonutChartView: View {
    let slices: [TrendSlice]

    let innerRatio: CGFloat = 0.55
    let gapDegrees: Double = 1.5

    struct Arc: Identifiable {
        let id = UUID()
        let color: Color
        let startDeg: Double
        let endDeg: Double
        let innerRadius: CGFloat
        let outerRadius: CGFloat
        let center: CGPoint

        var start: Angle { Angle(degrees: startDeg) }
        var end: Angle { Angle(degrees: endDeg) }
    }

    var body: some View {
        GeometryReader { geo in
            let size   = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outerR = size * 0.48
            let innerR = outerR * innerRatio
            let total  = max(1.0, slices.reduce(0) { $0 + $1.total })

            let arcs = makeArcs(total: total, center: center, innerR: innerR, outerR: outerR)

            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.04), lineWidth: outerR - innerR)
                    .frame(width: outerR * 2, height: outerR * 2)
                    .position(center)

                ForEach(arcs) { arc in
                    SegmentShape(center: arc.center,
                                 innerRadius: arc.innerRadius,
                                 outerRadius: arc.outerRadius,
                                 startAngle: arc.start,
                                 endAngle: arc.end)
                        .fill(arc.color)
                        .overlay(
                            SegmentShape(center: arc.center,
                                         innerRadius: arc.innerRadius,
                                         outerRadius: arc.outerRadius,
                                         startAngle: arc.start,
                                         endAngle: arc.end)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func makeArcs(total: Double, center: CGPoint, innerR: CGFloat, outerR: CGFloat) -> [Arc] {
        var acc = -90.0
        var out: [Arc] = []
        for s in slices {
            let frac = s.total / total
            let span = frac * 360.0
            let a0 = acc + gapDegrees / 2
            let a1 = acc + span - gapDegrees / 2
            if a1 > a0 {
                out.append(
                    Arc(color: s.category.tint,
                        startDeg: a0,
                        endDeg: a1,
                        innerRadius: innerR,
                        outerRadius: outerR,
                        center: center)
                )
            }
            acc += span
        }
        return out
    }
}

fileprivate struct SegmentShape: Shape {
    let center: CGPoint
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        p.closeSubpath()
        return p
    }
}

// MARK: - Spending Line Chart (same rendering method as HistoricalSavingsView)
fileprivate struct LineChartSpendingMonthly: View {
    let points: [(Date, Double)]   // oldest -> newest
    let accent: Color
    @Binding var selected: Int?    // selected point index

    private let monthDF: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()
    private let moneyFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencySymbol = "$"
        nf.maximumFractionDigits = 0
        nf.minimumFractionDigits = 0
        return nf
    }()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let values = points.map { $0.1 }
            let maxV = max(values.max() ?? 0, 1)
            let minV = 0.0
            let range = max(maxV - minV, 1)

            let coords: [CGPoint] = points.enumerated().map { (i, entry) in
                let x = CGFloat(i) / CGFloat(max(points.count - 1, 1)) * size.width
                let y = size.height - CGFloat((entry.1 - minV) / range) * size.height
                return CGPoint(x: x, y: y)
            }

            let path = Path { p in
                guard !coords.isEmpty else { return }
                p.addLines(coords)
            }

            let fill = Path { p in
                guard !coords.isEmpty else { return }
                p.addLines(coords)
                p.addLine(to: CGPoint(x: size.width, y: size.height))
                p.addLine(to: CGPoint(x: 0, y: size.height))
                p.closeSubpath()
            }

            ZStack {
                fill.fill(accent.opacity(0.15))
                path.stroke(accent, lineWidth: 2)

                ForEach(coords.indices, id: \.self) { i in
                    Circle()
                        .fill(i == selected ? accent : accent.opacity(0.6))
                        .frame(width: i == selected ? 10 : 6, height: i == selected ? 10 : 6)
                        .position(coords[i])
                }

                if let sel = selected, coords.indices.contains(sel) {
                    let pt = coords[sel]

                    Path { p in
                        p.move(to: CGPoint(x: pt.x, y: 0))
                        p.addLine(to: CGPoint(x: pt.x, y: size.height))
                    }
                    .stroke(accent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    VStack(spacing: 4) {
                        Text(monthDF.string(from: points[sel].0))
                            .font(.caption2.weight(.semibold))
                        Text(moneyFormatter.string(from: NSNumber(value: points[sel].1)) ?? "$\(Int(points[sel].1))")
                            .font(.caption2)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .position(x: clamp(pt.x, 50, size.width - 50),
                              y: max(pt.y - 28, 18))
                    .foregroundColor(.white)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let idx = indexForX(value.location.x, width: size.width, count: points.count)
                        if selected != idx { selected = idx }
                    }
                    .onEnded { _ in }
            )
            .simultaneousGesture(
                TapGesture().onEnded {
                    if let _ = selected { selected = nil }
                }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selectedA11yText)
    }

    private func indexForX(_ x: CGFloat, width: CGFloat, count: Int) -> Int {
        guard count > 1 else { return 0 }
        let t = max(0, min(1, x / max(width, 1)))
        let idx = Int(round(t * CGFloat(count - 1)))
        return max(0, min(count - 1, idx))
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(v, lo), hi)
    }

    private var selectedA11yText: String {
        guard let s = selected, points.indices.contains(s) else {
            return "Spending line chart"
        }
        let month = monthDF.string(from: points[s].0)
        let val = moneyFormatter.string(from: NSNumber(value: points[s].1)) ?? "$\(Int(points[s].1))"
        return "Spending \(month): \(val)"
    }
}

// MARK: - Local model used by this view
fileprivate struct TrendSlice: Identifiable, Hashable {
    let id = UUID()
    let category: ExpenseCategory
    let total: Double
}

