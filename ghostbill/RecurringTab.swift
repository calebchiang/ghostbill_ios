//
//  RecurringTab.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-11.
//

import SwiftUI

struct RecurringTab: View {
    @State private var selectedDate: Date? = Date()
    
    // bottom sheet drag state
    @State private var sheetOffset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0
    
    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let headerBG = Color(red: 0.16, green: 0.16, blue: 0.18) // lighter “zinc” strip
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let cardBG = Color(red: 0.14, green: 0.14, blue: 0.17)
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)
    
    private let sheetBG = Color(red: 0.26, green: 0.30, blue: 0.62)   // darker indigo background
    private let sheetBorder = Color(red: 0.14, green: 0.18, blue: 0.42) // bold indigo border


    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Recurring")
                                .font(.title2).fontWeight(.semibold)
                                .foregroundColor(textLight)
                            
                            Spacer()
                            
                            Button(action: {
                                // handle add action here
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(indigo)
                            }
                            .padding(.leading, 8)
                        }
                        .padding(.horizontal)
                        
                        WeekdayHeader(textMuted: textMuted)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 4)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .background(headerBG.ignoresSafeArea(edges: .top))
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.08)) // subtle divider
                            .frame(height: 1),
                        alignment: .bottom
                    )
                    
                    // CALENDAR
                    RecurringCalendar(
                        selection: $selectedDate,
                        accent: indigo,
                        textLight: textLight,
                        textMuted: textMuted,
                        cardBG: cardBG
                    )
                    .padding(.top, 12)
                    
                    Spacer(minLength: 12)
                }
                .background(bg.ignoresSafeArea())
                
                // BOTTOM SHEET
                bottomSheet(geo: geo)
            }
        }
    }
    
    @ViewBuilder
    private func bottomSheet(geo: GeometryProxy) -> some View {
        let peekHeight: CGFloat = 140
        let fullHeight = geo.size.height * 0.7
        
        // Lift above tab bar / FAB
        let bottomGutter = geo.safeAreaInsets.bottom + 90
        let baseOffset = geo.size.height - peekHeight - bottomGutter         // collapsed (down)
        let expandedOffset = geo.size.height - fullHeight - bottomGutter     // expanded (up)
        let travel = baseOffset - expandedOffset                              // positive
        
        // Follow finger while dragging, but clamp to our two bounds
        let currentOffset = baseOffset + sheetOffset + dragOffset
        let clampedOffset = min(baseOffset, max(expandedOffset, currentOffset))
        
        VStack(spacing: 0) {
            // ======= HANDLE AREA =======
            let handleHeight: CGFloat = 36
            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 40, height: 5)
            }
            .frame(height: handleHeight)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 2)
                    .updating($dragOffset) { value, state, _ in
                        let raw = value.translation.height
                        state = raw + rubberBandOverflow(
                            current: baseOffset + sheetOffset + raw,
                            lower: expandedOffset,
                            upper: baseOffset
                        )
                    }
                    .onEnded { value in
                        let v = value.predictedEndTranslation.height
                        let progress = (baseOffset - clampedOffset) / max(travel, 1)
                        let shouldExpand = (v < -300) || (v > 300 ? false : progress > 0.5)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            sheetOffset = shouldExpand ? -travel : 0
                        }
                    }
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    sheetOffset = (sheetOffset == 0) ? -travel : 0
                }
            }
            
            // CONTENT
            UpcomingPaymentsSheet(
                textLight: textLight,
                textMuted: textMuted,
                indigo: indigo
            )
        }
        .frame(height: fullHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(sheetBG) // 🔶 bold orange
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(sheetBorder, lineWidth: 1) // darker outline
                )
                .shadow(color: .black.opacity(0.35), radius: 12, y: -4)
        )
        .offset(y: clampedOffset)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.9), value: dragOffset)
        .zIndex(1)
    }
    
    // Rubber-band only when dragging beyond [lower, upper] bounds.
    private func rubberBandOverflow(current: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        if current < lower {
            let over = lower - current
            return -rubberBand(over)
        } else if current > upper {
            let over = current - upper
            return rubberBand(over)
        } else {
            return 0
        }
    }
    private func rubberBand(_ x: CGFloat, c: CGFloat = 0.55) -> CGFloat {
        (1 - (1 / (x * c + 1)))
    }
}

struct WeekdayHeader: View {
    var textMuted: Color

    var body: some View {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1
        let ordered = first == 0 ? symbols : Array(symbols[first...] + symbols[..<first])

        HStack {
            ForEach(ordered, id: \.self) { w in
                Text(w)
                    .font(.footnote)
                    .foregroundColor(textMuted)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
}

