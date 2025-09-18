//
//  HistoricalSavingsView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-13.
//

import SwiftUI
import Supabase

struct HistoricalSavingsView: View {
    // Inputs
    var monthsBack: Int = 12
    var reloadKey: UUID = UUID()
    /// Called when the user taps "Report income" for a given month.
    var onReportIncome: ((Date) -> Void)?

    // State
    @State private var loading = true
    @State private var history: SavingsHistory? = nil
    @State private var errorText: String? = nil

    // Selection state for interactive chart
    @State private var selectedIndex: Int? = nil

    // Navigation
    @State private var showHistoryList = false

    // Style
    private let cardBG = Color(red: 0.14, green: 0.14, blue: 0.17)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let accent = Color.mint

    var body: some View {
        // Card container
        VStack(alignment: .leading, spacing: 14) {
            // Title
            HStack {
                Text("Savings history")
                    .font(.headline)
                    .foregroundColor(textLight)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(textMuted)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHidden(true)
            }

            // Chart area
            Group {
                if loading {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 220)
                        .redacted(reason: .placeholder)
                } else if let h = history, !h.reported.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        LineChartMonthlySavings(
                            points: h.reported.map { ($0.monthStart, $0.savings) },
                            accent: accent,
                            selected: $selectedIndex
                        )
                        .frame(height: 220)

                        // X-axis (sparse month labels using reported points only)
                        HStack(spacing: 0) {
                            ForEach(xLabels(for: h.reported), id: \.self) { lbl in
                                Text(lbl)
                                    .font(.caption2)
                                    .foregroundColor(textMuted)
                                Spacer(minLength: 0)
                            }
                        }

                        // Average of plotted points
                        let avg: Double = {
                            let vals = h.reported.map { $0.savings }
                            guard !vals.isEmpty else { return 0 }
                            return vals.reduce(0, +) / Double(vals.count)
                        }()

                        Divider().background(Color.white.opacity(0.08)).padding(.top, 4)

                        HStack {
                            Text("Average monthly savings")
                                .font(.subheadline)
                                .foregroundColor(textMuted)
                            Spacer()
                            Text(formatNumber(avg))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(textLight)
                                .accessibilityLabel("Average monthly savings \(formatNumber(avg))")
                        }
                    }
                } else {
                    VStack(spacing: 6) {
                        Text("No savings to chart yet")
                            .font(.subheadline)
                            .foregroundColor(textMuted)
                        Text("Report income for a month to calculate savings.")
                            .font(.caption)
                            .foregroundColor(textMuted.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                }
            }

            // Unreported months list (only months with activity but no income)
            if let h = history, !h.unreported.isEmpty {
                Divider().background(Color.white.opacity(0.08)).padding(.vertical, 4)

                Text("Months missing income")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(textLight)

                VStack(spacing: 8) {
                    ForEach(h.unreported, id: \.self) { monthStart in
                        HStack {
                            Text(monthLabel(from: monthStart))
                                .foregroundColor(textMuted)
                                .font(.subheadline)

                            Spacer()

                            Button {
                                // 👉 Open the sheet pre-set to this month
                                onReportIncome?(monthStart)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Report income")
                                        .font(.footnote.weight(.semibold))
                                }
                                .foregroundColor(textLight)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(accent.opacity(0.22))
                                )
                            }
                            .accessibilityLabel("Report income for \(monthLabel(from: monthStart))")
                        }
                    }
                }
            }

            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22).fill(cardBG)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 8)

        // Make the whole card tappable to push the list
        .contentShape(Rectangle())
        .onTapGesture { showHistoryList = true }

        // ✅ Modern navigation (requires being inside a NavigationStack higher up)
        .navigationDestination(isPresented: $showHistoryList) {
            SavingsHistoryListView(
                monthsBack: max(monthsBack, 12),
                reloadKey: reloadKey,
                onReportIncome: onReportIncome
            )
        }

        // Load/refresh when the reloadKey changes
        .task(id: reloadKey) {
            await loadHistory()
        }
        // Reset selection when data reloads
        .onChange(of: reloadKey) { _ in selectedIndex = nil }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Data

    private func loadHistory() async {
        await MainActor.run {
            loading = true
            errorText = nil
            history = nil
            selectedIndex = nil
        }

        do {
            // Resolve user id from session
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id

            let result = try await TransactionsService.shared.getSavingsHistory(
                userId: userId,
                monthsBack: monthsBack,
                now: Date(),
                timezone: .current
            )
            await MainActor.run {
                history = result
                loading = false
            }
        } catch {
            await MainActor.run {
                loading = false
                errorText = error.localizedDescription
            }
        }
    }

    // MARK: - Labels & a11y

    private func xLabels(for points: [SavingsHistory.Point]) -> [String] {
        guard !points.isEmpty else { return [] }
        let f = DateFormatter()
        f.dateFormat = "MMM"
        let step = max(1, points.count / 5) // ~5 labels
        return stride(from: 0, to: points.count, by: step).map { f.string(from: points[$0].monthStart) }
    }

    private var accessibilityText: String {
        if loading { return "Loading savings history" }
        guard let h = history else { return "Savings history unavailable" }
        if h.reported.isEmpty { return "No savings available to chart" }
        let minVal = Int(h.reported.map { $0.savings }.min() ?? 0)
        let maxVal = Int(h.reported.map { $0.savings }.max() ?? 0)
        return "Savings history from \(monthLabel(from: h.reported.first!.monthStart)) to \(monthLabel(from: h.reported.last!.monthStart)). Minimum \(minVal), maximum \(maxVal)."
    }

    // MARK: - Formatting

    private func formatNumber(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        nf.minimumFractionDigits = 0
        return nf.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

// MARK: - Chart

private struct LineChartMonthlySavings: View {
    let points: [(Date, Double)]   // oldest -> newest
    let accent: Color
    @Binding var selected: Int?    // selected point index

    // Formatters
    private let monthDF: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()
    private let numberFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
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

            // Precompute point positions
            let coords: [CGPoint] = points.enumerated().map { (i, entry) in
                let x = CGFloat(i) / CGFloat(max(points.count - 1, 1)) * size.width
                let y = size.height - CGFloat((entry.1 - minV) / range) * size.height
                return CGPoint(x: x, y: y)
            }

            // Stroke path
            let path = Path { p in
                guard !coords.isEmpty else { return }
                p.addLines(coords)
            }

            // Fill path (area)
            let fill = Path { p in
                guard !coords.isEmpty else { return }
                p.addLines(coords)
                p.addLine(to: CGPoint(x: size.width, y: size.height))
                p.addLine(to: CGPoint(x: 0, y: size.height))
                p.closeSubpath()
            }

            ZStack {
                // Area & line
                fill.fill(accent.opacity(0.15))
                path.stroke(accent, lineWidth: 2)

                // Dots at points
                ForEach(coords.indices, id: \.self) { i in
                    Circle()
                        .fill(i == selected ? accent : accent.opacity(0.6))
                        .frame(width: i == selected ? 10 : 6, height: i == selected ? 10 : 6)
                        .position(coords[i])
                }

                // Selection marker + tooltip
                if let sel = selected, coords.indices.contains(sel) {
                    let pt = coords[sel]

                    // Vertical guide
                    Path { p in
                        p.move(to: CGPoint(x: pt.x, y: 0))
                        p.addLine(to: CGPoint(x: pt.x, y: size.height))
                    }
                    .stroke(accent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    // Tooltip
                    VStack(spacing: 4) {
                        Text(monthDF.string(from: points[sel].0))
                            .font(.caption2.weight(.semibold))
                        Text(numberFormatter.string(from: NSNumber(value: points[sel].1)) ?? "\(Int(points[sel].1))")
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
            // Gestures: tap or drag to change selection
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let idx = indexForX(value.location.x, width: size.width, count: points.count)
                        if selected != idx { selected = idx }
                    }
                    .onEnded { _ in
                        // keep selection; tap outside to clear (optional)
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        if let _ = selected {
                            selected = nil
                        }
                    }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selectedA11yText)
    }

    // MARK: - Helpers

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
            return "Savings line chart"
        }
        let month = monthDF.string(from: points[s].0)
        let val = numberFormatter.string(from: NSNumber(value: points[s].1)) ?? "\(Int(points[s].1))"
        return "Savings \(month): \(val)"
    }
}

// MARK: - Small helpers

private func monthLabel(from date: Date) -> String {
    let df = DateFormatter()
    df.dateFormat = "LLLL yyyy"
    return df.string(from: date)
}

