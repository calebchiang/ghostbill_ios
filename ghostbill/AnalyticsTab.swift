//
//  AnalyticsTab.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI

struct AnalyticsTab: View {
    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)

    var body: some View {
        VStack(spacing: 8) {
            Text("Analytics")
                .font(.title2)
                .foregroundColor(textLight)
            Text("See trends, categories, and insights.")
                .foregroundColor(textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bg.ignoresSafeArea())
    }
}
