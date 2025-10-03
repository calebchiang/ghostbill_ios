//
//  Tutorial.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-10-02.
//

import SwiftUI

struct TutorialSlide: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
                .padding(.bottom, 4)

            Text("Awareness is the first step.")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tracking every dollar you spend is the first step towards financial freedom.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .offset(y: -16)
    }
}

