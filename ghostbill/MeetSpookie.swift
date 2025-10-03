//
//  MeetSpookie.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-10-02.
//

import SwiftUI

struct MeetSpookieSlide: View {
    var body: some View {
        VStack(spacing: 12) {
            Image("happy_ghost")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            Text("Meet Spookie the ghost!")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .offset(y: -16)
    }
}

struct SpookieHealthIntroSlide: View {
    @State private var showDetail = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Keep Spookie healthy.")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                Text("As you log purchases, Spookie will learn your usual monthly spending.")
                Text("Spend a bit more and he gets concerned; spend a lot more and he looks drained.")
            }
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 320)
            .opacity(showDetail ? 1 : 0)

            Image("happy_spookie")
                .resizable()
                .scaledToFit()
                .frame(width: 250, height: 250)
                .opacity(showDetail ? 1 : 0)
        }
        .padding(.horizontal)
        .offset(y: -4)
        .onAppear {
            showDetail = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showDetail = true
                }
            }
        }
    }
}
