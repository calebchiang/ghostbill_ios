//
//  CurrencySelect.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-10-02.
//

import SwiftUI

struct CurrencySelect: View {
    let currencies: [String]
    @Binding var index: Int

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose your currency")
                .font(.title3)
                .fontWeight(.semibold)

            Picker("Currency", selection: $index) {
                ForEach(currencies.indices, id: \.self) { i in
                    Text(currencies[i]).tag(i)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 140)
            .id("currencyPicker")
        }
    }
}
