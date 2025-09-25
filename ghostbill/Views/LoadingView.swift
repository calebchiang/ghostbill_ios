//
//  LoadingView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-25.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("ghostbill_logo_transparent")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .opacity(0.7)
        }
    }
}
