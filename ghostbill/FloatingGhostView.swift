//
//  FloatingGhostView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-09.
//

import SwiftUI

struct FloatingGhostView: View {
    @State private var floatUp = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.25))
                .frame(width: floatUp ? 60 : 90, height: floatUp ? 15 : 25)
                .offset(y: 50)
                .blur(radius: 6)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: floatUp)

            Image("ghostbill_logo_transparent")
                .resizable()
                .scaledToFit()
                .frame(width: 130, height: 130)
                .offset(y: floatUp ? -20 : 0)
                .animation(.easeInOut(duration:0.7).repeatForever(autoreverses: true), value: floatUp)
        }
        .onAppear {
            floatUp.toggle()
        }
    }
}
