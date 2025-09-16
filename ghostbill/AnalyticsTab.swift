//
//  AnalyticsTab.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI

enum AnalyticsDimension: String, CaseIterable, Identifiable {
    case spending
    case trends

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spending: return "Spending"
        case .trends:   return "Trends"
        }
    }
}

struct AnalyticsTab: View {
    private let bg        = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let accent    = Color.mint

    @AppStorage("analytics.selectedDimension")
    private var selectedRaw: String = AnalyticsDimension.spending.rawValue

    private var selectedBinding: Binding<AnalyticsDimension> {
        Binding(
            get: { AnalyticsDimension(rawValue: selectedRaw) ?? .spending },
            set: { selectedRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Analytics")
                                .font(.title.bold())
                                .foregroundColor(textLight)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        Picker("", selection: selectedBinding) {
                            ForEach(AnalyticsDimension.allCases) { dim in
                                Text(dim.label).tag(dim)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(accent)
                        .padding(.horizontal, 16)

                        switch selectedBinding.wrappedValue {
                        case .spending:
                            TrendsAnalyticsView()
                                .padding(.horizontal, 16)
                        case .trends:
                            SpendingAnalyticsView()
                                .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

