//
//  UpcomingPaymentsSheet.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-11.
//

import SwiftUI

struct UpcomingPaymentsSheet: View {
    let textLight: Color
    let textMuted: Color
    let indigo: Color

    private let sheetBG = Color(red: 0.26, green: 0.30, blue: 0.62)   // darker indigo background

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming payments")
                .font(.headline)
                .foregroundColor(textLight)

            List {
                HStack {
                    Circle().fill(indigo.opacity(0.20))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "repeat")
                                .foregroundColor(indigo)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spotify")
                            .foregroundColor(textLight)
                        Text("Sep 22 • $12.99")
                            .font(.caption)
                            .foregroundColor(textMuted)
                    }
                }
                .listRowBackground(Color.clear)

                HStack {
                    Circle().fill(indigo.opacity(0.20))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "repeat")
                                .foregroundColor(indigo)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Netflix")
                            .foregroundColor(textLight)
                        Text("Oct 1 • $15.49")
                            .font(.caption)
                            .foregroundColor(textMuted)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden) // let the orange show through
        }
        .padding()
        .background(sheetBG) // 🔶 bold orange inside
    }
}

