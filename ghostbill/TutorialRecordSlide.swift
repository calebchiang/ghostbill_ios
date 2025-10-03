//
//  TutorialRecordSlide.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-10-02.
//

import SwiftUI

struct TutorialRecordSlide: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Two ways to record a purchase")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scan a receipt")
                            .font(.subheadline.weight(.semibold))
                        Text("Tap the scan icon in the bottom center to record an expense.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add it manually")
                            .font(.subheadline.weight(.semibold))
                        Text("Press the + icon on Home to add income or an expense.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: 320, alignment: .leading)
            .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity)
        .offset(y: -16)
    }
}

