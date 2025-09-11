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
    @State private var showReview = false
    @State private var isLoadingScan = false
    @State private var scannedImage: UIImage? = nil
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

            if isLoadingScan {
                ZStack {
                    bg.ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: indigo))
                            .scaleEffect(1.5)
                        Text("Processing receipt…")
                            .foregroundColor(textLight)
                            .font(.headline)
                    }
                }
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            ReceiptScannerView(
                onComplete: { images in
                    scannedImage = images.first
                    showScanner = false
                    isLoadingScan = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        isLoadingScan = false
                        showReview = true
                    }
                },
                onCancel: {
                    showScanner = false
                },
                onError: { _ in
                    showScanner = false
                }
            )
        }
        .sheet(isPresented: $showReview) {
            ReviewTransactionView(
                onSave: { _, _, _, _, _ in
                    showReview = false
                    scannedImage = nil
                },
                onScanAgain: {
                    showReview = false
                    scannedImage = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showScanner = true
                    }
                },
                onCancel: {
                    showReview = false
                    scannedImage = nil
                }
            )
        }
    }
}

