//
//  ReviewTransactionView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI

struct ReviewTransactionView: View {
    var onSave: (_ merchant: String?, _ amount: String?, _ date: Date?, _ category: String?, _ notes: String?) -> Void
    var onScanAgain: () -> Void
    var onCancel: () -> Void

    @State private var merchant: String = ""
    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var category: String = ""
    @State private var notes: String = ""

    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    private let categories = ["", "Dining", "Groceries", "Fuel", "Shopping", "Bills", "Transport", "Entertainment", "Health", "Other"]

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Review Transaction")
                        .font(.title3).bold()
                        .foregroundColor(textLight)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Merchant").foregroundColor(textMuted).font(.footnote)
                        TextField("Enter merchant", text: $merchant)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .padding(12)
                            .background(Color.black.opacity(0.25))
                            .cornerRadius(12)
                            .foregroundColor(textLight)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount").foregroundColor(textMuted).font(.footnote)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(Color.black.opacity(0.25))
                            .cornerRadius(12)
                            .foregroundColor(textLight)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date").foregroundColor(textMuted).font(.footnote)
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                            .padding(12)
                            .background(Color.black.opacity(0.25))
                            .cornerRadius(12)
                            .colorScheme(.dark)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category").foregroundColor(textMuted).font(.footnote)
                        Picker("Select category", selection: $category) {
                            ForEach(categories, id: \.self) { c in
                                Text(c.isEmpty ? "Uncategorized" : c).tag(c)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(12)
                        .foregroundColor(textLight)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes").foregroundColor(textMuted).font(.footnote)
                        TextField("Optional", text: $notes, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                            .padding(12)
                            .background(Color.black.opacity(0.25))
                            .cornerRadius(12)
                            .foregroundColor(textLight)
                    }
                }

                Spacer(minLength: 8)

                VStack(spacing: 10) {
                    Button {
                        onSave(merchant.isEmpty ? nil : merchant,
                               amount.isEmpty ? nil : amount,
                               date,
                               category.isEmpty ? nil : category,
                               notes.isEmpty ? nil : notes)
                    } label: {
                        Text("Save Transaction")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(indigo)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }

                    Button {
                        onScanAgain()
                    } label: {
                        Text("Scan Again")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.black.opacity(0.35))
                            .foregroundColor(textLight)
                            .cornerRadius(14)
                    }

                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundColor(textMuted)
                    }
                }
            }
            .padding(16)
            .background(bg.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
    }
}
