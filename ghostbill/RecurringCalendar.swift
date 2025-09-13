//
//  RecurringCalendar.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-11.
//

import SwiftUI
import Foundation

struct RecurringCalendar: View {
    @Binding var selection: Date?

    var accent: Color
    var textLight: Color
    var textMuted: Color
    var cardBG: Color

    var markedDayKeys: Set<String> = []

    private let monthsBefore = 12
    private let monthsAfter = 12

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 32) {
                    ForEach(monthRange(), id: \.self) { month in
                        VStack(spacing: 0) {
                            Text(month.formatted(.dateTime.year().month(.wide)))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(textLight)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.bottom, 4)

                            MonthGrid(
                                month: month,
                                selection: $selection,
                                accent: accent,
                                textLight: textLight,
                                textMuted: textMuted,
                                markedDayKeys: markedDayKeys
                            )
                        }
                        .id(month)
                    }
                }
                .padding(.vertical, 12)
            }
            .onAppear {
                proxy.scrollTo(Date().startOfMonth(), anchor: .top)
            }
        }
    }

    private func monthRange() -> [Date] {
        let now = Date().startOfMonth()
        let cal = Calendar.current
        var months: [Date] = []
        for offset in (-monthsBefore)...monthsAfter {
            if let d = cal.date(byAdding: .month, value: offset, to: now) {
                months.append(d.startOfMonth())
            }
        }
        return months
    }
}

private struct MonthGrid: View {
    let month: Date
    @Binding var selection: Date?

    var accent: Color
    var textLight: Color
    var textMuted: Color
    var markedDayKeys: Set<String>

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0, alignment: .center), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(cellsForMonth(), id: \.self) { cell in
                let hasMarker: Bool = {
                    guard let d = cell.date, cell.inMonth else { return false }
                    return markedDayKeys.contains(dayKey(d))
                }()

                DayCell(
                    cell: cell,
                    isSelected: isSelected(cell.date),
                    accent: accent,
                    textLight: textLight,
                    textMuted: textMuted,
                    hasMarker: hasMarker
                )
                .frame(height: 70)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard let d = cell.date, cell.inMonth else { return }
                    selection = d  // parent decides whether to show popup
                }
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color.white.opacity(0.15)),
                    alignment: .bottom
                )
            }
        }
        .padding(.horizontal, 4)
    }

    private func isSelected(_ date: Date?) -> Bool {
        guard let date, let sel = selection else { return false }
        return Calendar.current.isDate(date, inSameDayAs: sel)
    }

    private func cellsForMonth() -> [DayCellModel] {
        let cal = Calendar.current
        let start = month.startOfMonth()
        let daysCount = start.daysInMonth()
        let offset = start.weekdayIndexForGrid()

        var cells: [DayCellModel] = []
        for _ in 0..<offset {
            cells.append(.init(date: nil, inMonth: false, isToday: false))
        }

        for day in 1...daysCount {
            if let date = cal.date(byAdding: .day, value: day - 1, to: start) {
                cells.append(.init(
                    date: date,
                    inMonth: true,
                    isToday: cal.isDateInToday(date)
                ))
            }
        }

        while cells.count % 7 != 0 {
            cells.append(.init(date: nil, inMonth: false, isToday: false))
        }

        return cells
    }

    private func dayKey(_ d: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}

struct DayCellModel: Hashable {
    let date: Date?
    let inMonth: Bool
    let isToday: Bool
}

private struct DayCell: View {
    let cell: DayCellModel
    let isSelected: Bool
    let accent: Color
    let textLight: Color
    let textMuted: Color
    let hasMarker: Bool

    /// green dot for upcoming payment
    private let markerGreen = Color(red: 0.25, green: 0.82, blue: 0.47)

    var body: some View {
        ZStack {
            // Selection/today background behind the number
            if isSelected {
                Circle()
                    .fill(accent)
                    .frame(width: 32, height: 32)
            } else if cell.isToday && cell.inMonth {
                Circle()
                    .stroke(accent.opacity(0.8), lineWidth: 1.5)
                    .frame(width: 32, height: 32)
            }

            // Day number
            Text(dayString)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(fgColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(cell.inMonth ? 1.0 : 0.3)
        // Green marker dot centered under the number
        .overlay(alignment: .bottom) {
            if hasMarker && cell.inMonth {
                Circle()
                    .fill(markerGreen)
                    .frame(width: 8, height: 8)
                    .padding(.bottom, 8) // adjust higher/lower by changing this value
            }
        }
    }

    private var dayString: String {
        guard let d = cell.date else { return "" }
        return String(Calendar.current.component(.day, from: d))
    }

    private var fgColor: Color {
        isSelected ? .white : (cell.inMonth ? textLight : textMuted)
    }
}

// MARK: - Date helpers
extension Date {
    func startOfMonth() -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: self)
        return cal.date(from: comps) ?? self
    }

    func daysInMonth() -> Int {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: self.startOfMonth()) else { return 30 }
        return range.count
    }

    func weekdayIndexForGrid() -> Int {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: self.startOfMonth())
        let first = cal.firstWeekday
        return (weekday - first + 7) % 7
    }

    func addingMonths(_ m: Int) -> Date {
        Calendar.current
            .date(byAdding: .month, value: m, to: self.startOfMonth())?
            .startOfMonth() ?? self
    }
}

