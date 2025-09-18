//
//  RecurringTab.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-11.
//

import SwiftUI
import Supabase

struct RecurringTab: View {
    @State private var selectedDate: Date? = Date()

    @State private var showAddRecurring = false

    @State private var sheetOffset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    @State private var upcoming: [RecurringTransactionsService.DBRecurringTransaction] = []

    @State private var showDayPopup: Bool = false
    @State private var popupPayments: [RecurringTransactionsService.DBRecurringTransaction] = []
    @State private var popupDate: Date? = nil

    @State private var selectedRecurring: RecurringTransactionsService.DBRecurringTransaction?

    @State private var showRecurringTour = false

    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let headerBG = Color(red: 0.16, green: 0.16, blue: 0.18)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let cardBG = Color(red: 0.14, green: 0.14, blue: 0.17)
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    private let sheetBG = Color(red: 0.11, green: 0.11, blue: 0.13)
    private let sheetBorder = Color(red: 0.11, green: 0.11, blue: 0.13)

    @State private var currencySymbol: String = "$"

    var body: some View {
        GeometryReader { geo in
            ZStack {

                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Recurring")
                                .font(.title2).fontWeight(.semibold)
                                .foregroundColor(textLight)

                            Spacer()

                            Button(action: {
                                showAddRecurring = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(textLight)
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
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1),
                        alignment: .bottom
                    )

                    RecurringCalendar(
                        selection: $selectedDate,
                        accent: indigo,
                        textLight: textLight,
                        textMuted: textMuted,
                        cardBG: cardBG,
                        markedDayKeys: markedDayKeys()
                    )
                    .padding(.top, 12)
                    .onChange(of: selectedDate) { newValue in
                        guard let date = newValue else { return }
                        let key = dayKey(date)
                        let map = paymentsByDayKey()
                        if let payments = map[key], !payments.isEmpty {
                            popupPayments = payments
                            popupDate = date
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.95)) {
                                showDayPopup = true
                            }
                        }
                    }

                    Spacer(minLength: 12)
                }
                .background(bg.ignoresSafeArea())

                bottomSheet(geo: geo)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                if showDayPopup {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.95)) {
                                showDayPopup = false
                            }
                        }
                        .zIndex(100)

                    VStack(spacing: 14) {
                        Text(popupTitle())
                            .font(.headline)
                            .foregroundColor(textLight)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if popupPayments.isEmpty {
                            Text("No payments on this date.")
                                .foregroundColor(textMuted)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(popupPayments, id: \.id) { item in
                                    Button {
                                        selectedRecurring = item
                                        withAnimation(.spring(response: 0.22, dampingFraction: 0.95)) {
                                            showDayPopup = false
                                        }
                                    } label: {
                                        HStack {
                                            Text(item.merchant_name)
                                                .foregroundColor(textLight)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            Spacer()
                                            Text(formatAmount(item.amount))
                                                .foregroundColor(textLight)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Button(action: {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.95)) {
                                showDayPopup = false
                            }
                        }) {
                            Text("Close")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(indigo)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .padding(.top, 6)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(red: 0.13, green: 0.13, blue: 0.16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.45), radius: 20)
                    )
                    .frame(maxWidth: 360)
                    .padding(.horizontal, 24)
                    .zIndex(101)
                    .transition(.scale.combined(with: .opacity))
                }

                if showRecurringTour {
                    RecurringTabTourView(onDismiss: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showRecurringTour = false
                        }
                    })
                    .transition(.opacity)
                    .zIndex(200)
                }
            }
        }
        .task {
            await loadUpcoming()
            await checkRecurringTourFlag()
            await loadCurrencySymbol()
        }
        .sheet(isPresented: $showAddRecurring) {
            ReviewRecurringTransactionView(
                onCancel: { showAddRecurring = false },
                onSaved: {
                    showAddRecurring = false
                    Task { await loadUpcoming() }
                }
            )
        }
        .sheet(item: $selectedRecurring) { rec in
            NavigationStack {
                RecurringPaymentView(
                    recurring: rec,
                    onUpdated: { _ in
                        Task { await loadUpcoming() }
                    },
                    onDeleted: { id in
                        upcoming.removeAll { $0.id == id }
                        selectedRecurring = nil
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func bottomSheet(geo: GeometryProxy) -> some View {
        let peekHeight: CGFloat = 220
        let fullHeight = geo.size.height * 0.7

        let bottomGutter = geo.safeAreaInsets.bottom + 90
        let baseOffset = geo.size.height - peekHeight - bottomGutter
        let expandedOffset = geo.size.height - fullHeight - bottomGutter
        let travel = baseOffset - expandedOffset

        let currentOffset = baseOffset + sheetOffset + dragOffset
        let clampedOffset = min(baseOffset, max(expandedOffset, currentOffset))

        let isExpanded = sheetOffset != 0

        VStack(spacing: 0) {
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

            UpcomingPaymentsSheet(
                textLight: textLight,
                textMuted: textMuted,
                indigo: indigo,
                items: upcoming,
                showContent: isExpanded,
                onSelect: { rec in
                    selectedRecurring = rec
                }
            )
        }
        .frame(height: fullHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(sheetBG)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(sheetBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 12, y: -4)
        )
        .offset(y: clampedOffset)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.9), value: dragOffset)
        .zIndex(1)
    }

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

    private func loadUpcoming() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id
            let rows = try await RecurringTransactionsService.shared.listRecurringTransactions(userId: userId)
            await MainActor.run {
                self.upcoming = rows
            }
        } catch {
            await MainActor.run {
                self.upcoming = []
            }
        }
    }

    private func checkRecurringTourFlag() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id
            let seen = try await ProfilesService.shared.hasSeenRecurringTour(userId: userId)
            await MainActor.run { self.showRecurringTour = !seen }
        } catch {
            await MainActor.run { self.showRecurringTour = false }
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

    private func dayKey(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    private func paymentsByDayKey() -> [String: [RecurringTransactionsService.DBRecurringTransaction]] {
        var map: [String: [RecurringTransactionsService.DBRecurringTransaction]] = [:]
        let inF = DateFormatter()
        inF.calendar = Calendar(identifier: .gregorian)
        inF.locale = Locale(identifier: "en_US_POSIX")
        inF.timeZone = TimeZone.current
        inF.dateFormat = "yyyy-MM-dd"

        for item in upcoming {
            if let d = inF.date(from: item.next_date) {
                let key = dayKey(d)
                map[key, default: []].append(item)
            }
        }
        return map
    }

    private func markedDayKeys() -> Set<String> {
        Set(paymentsByDayKey().keys)
    }

    private func popupTitle() -> String {
        guard let d = popupDate else { return "Payments" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "Payments on \(f.string(from: d))"
    }

    private func formatAmount(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = currencySymbol
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: NSNumber(value: amount)) ?? "\(currencySymbol)\(String(format: "%.2f", amount))"
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

