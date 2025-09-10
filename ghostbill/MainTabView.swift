//
//  MainTabView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable { case home, recurring, savings, analytics }

    @State private var selected: Tab = .home
    @State private var showScanner = false
    @EnvironmentObject var session: SessionStore

    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            TabView(selection: $selected) {
                HomeTab()
                    .tag(Tab.home)
                    .tabItem {
                        Image(systemName: selected == .home ? "house.fill" : "house")
                        Text("Home")
                    }

                RecurringTab()
                    .tag(Tab.recurring)
                    .tabItem {
                        Image(systemName: "repeat.circle")
                        Text("Recurring")
                    }

                SavingsTab()
                    .tag(Tab.savings)
                    .tabItem {
                        Image(systemName: "banknote")
                        Text("Savings")
                    }

                AnalyticsTab()
                    .tag(Tab.analytics)
                    .tabItem {
                        Image(systemName: "chart.bar.xaxis")
                        Text("Analytics")
                    }
            }
            .tint(indigo)

            VStack {
                Spacer()
                Button {
                    showScanner = true
                } label: {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(indigo)
                        .clipShape(Circle())
                        .shadow(color: indigo.opacity(0.4), radius: 12, x: 0, y: 8)
                }
                .padding(.bottom, 30)
                .accessibilityLabel("Scan receipt")
            }
            .allowsHitTesting(true)
        }
        .sheet(isPresented: $showScanner) {
            ScannerPlaceholderView()
        }
    }

    private struct ScannerPlaceholderView: View {
        private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
        private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
        private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)

        var body: some View {
            VStack(spacing: 12) {
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 42))
                    .foregroundColor(textLight)
                Text("Scanner coming soon")
                    .font(.headline)
                    .foregroundColor(textLight)
                Text("This will open the camera to scan receipts and auto-create transactions.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(textMuted)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(bg.ignoresSafeArea())
        }
    }
}

