//
//  FloatingGhostView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-09.
//

import SwiftUI

struct FloatingGhostView: View {
    @State private var floatUp = false
    private let bounce = Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true)

    var body: some View {
        ZStack {
            // Shadow (smaller & flatter when ghost is up)
            Ellipse()
                .fill(Color.black.opacity(0.25))
                .frame(width: floatUp ? 60 : 90, height: floatUp ? 15 : 25)
                .offset(y: 50)
                .blur(radius: 6)
                .animation(bounce, value: floatUp)

            // Ghost
            Image("ghostbill_logo_transparent")
                .resizable()
                .scaledToFit()
                .frame(width: 130, height: 130)
                .offset(y: floatUp ? -20 : 0)
                .animation(bounce, value: floatUp)
        }
        .onAppear { floatUp.toggle() }
    }
}

