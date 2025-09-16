//
//  AddTransactionView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-16.
//

import SwiftUI

enum TransactionType: String, CaseIterable, Hashable {
    case income
    case expense

    var displayName: String {
        switch self {
        case .income:  return "Income"
        case .expense: return "Expense"
        }
    }
}

struct AddTransactionView: View {
    // Callbacks
    var onSave: (_ merchant: String?, _ amount: String?, _ date: Date?, _ type: TransactionType, _ category: ExpenseCategory, _ notes: String?) -> Void
    var onCancel: () -> Void

    // State
    @State private var merchant: String
    @State private var amount: String
    @State private var date: Date
    @State private var type: TransactionType
    @State private var category: ExpenseCategory
    @State private var notes: String

    // Palette (match ReviewTransactionView)
    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    // Initializer (optional prefill support)
    init(
        initialMerchant: String? = nil,
        initialAmount: String? = nil,
        initialDate: Date? = nil,
        initialType: TransactionType = .expense,
        initialCategory: ExpenseCategory = .other,
        initialNotes: String? = nil,
        onSave: @escaping (_ merchant: String?, _ amount: String?, _ date: Date?, _ type: TransactionType, _ category: ExpenseCategory, _ notes: String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onCancel = onCancel

        _merchant = State(initialValue: initialMerchant ?? "")
        _amount   = State(initialValue: initialAmount ?? "")
        _date     = State(initialValue: initialDate ?? Date())
        _type     = State(initialValue: initialType)
        _category = State(initialValue: initialCategory)
        _notes    = State(initialValue: initialNotes ?? "")
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add transaction")
                        .font(.title3).bold()
                        .foregroundColor(textLight)

                    // Merchant
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

                    // Amount
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount").foregroundColor(textMuted).font(.footnote)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(Color.black.opacity(0.25))
                            .cornerRadius(12)
                            .foregroundColor(textLight)
                    }

                    // Transaction Type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transaction Type").foregroundColor(textMuted).font(.footnote)
                        Picker("Select type", selection: $type) {
                            ForEach(TransactionType.allCases, id: \.self) { t in
                                Text(t.displayName).tag(t)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(12)
                        .foregroundColor(textLight)
                    }

                    // Category — placed below Transaction Type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category").foregroundColor(textMuted).font(.footnote)
                        Picker("Select category", selection: $category) {
                            ForEach(ExpenseCategory.allCases, id: \.self) { c in
                                Text(c.displayName).tag(c)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(12)
                        .foregroundColor(textLight)
                    }

                    // Date
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date").foregroundColor(textMuted).font(.footnote)
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                            .padding(12)
                            .background(Color.black.opacity(0.25))
                            .cornerRadius(12)
                            .colorScheme(.dark)
                    }

                    // Notes
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

                // Actions
                VStack(spacing: 10) {
                    Button {
                        onSave(
                            merchant.isEmpty ? nil : merchant,
                            amount.isEmpty ? nil : amount,
                            date,
                            type,
                            category,
                            notes.isEmpty ? nil : notes
                        )
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
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }
}

// Pretty names for categories
private extension ExpenseCategory {
    var displayName: String {
        switch self {
        case .groceries:     return "Groceries"
        case .coffee:        return "Coffee"
        case .dining:        return "Dining"
        case .transport:     return "Transport"
        case .fuel:          return "Fuel"
        case .shopping:      return "Shopping"
        case .utilities:     return "Utilities"
        case .housing:       return "Housing"
        case .entertainment: return "Entertainment"
        case .travel:        return "Travel"
        case .income:        return "Income"
        case .other:         return "Other"
        }
    }
}

