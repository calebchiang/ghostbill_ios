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

        // If the initial type is income, force initial category to .income
        let resolvedCategory: ExpenseCategory = (initialType == .income) ? .income : initialCategory
        _category = State(initialValue: resolvedCategory)

        _notes    = State(initialValue: initialNotes ?? "")
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add transaction")
                        .font(.title3).bold()
                        .foregroundColor(textLight)

                    // Transaction Type (tab-style) — ABOVE Merchant
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transaction Type")
                            .foregroundColor(textMuted)
                            .font(.footnote)

                        HStack(spacing: 8) {
                            ForEach(TransactionType.allCases, id: \.self) { t in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        type = t
                                    }
                                } label: {
                                    Text(t.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 14)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10) // subtle rounding
                                                .fill(type == t ? indigo : Color.black.opacity(0.25))
                                        )
                                        .foregroundColor(type == t ? .white : textLight)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                }
                                .accessibilityAddTraits(type == t ? .isSelected : [])
                            }
                        }
                    }

                    // Merchant — hidden for income (we'll default to "Income" on save)
                    if type == .expense {
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

                    // Category — auto-select Income for income type
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
                        .disabled(type == .income) // lock when income to avoid accidental change
                        .opacity(type == .income ? 0.7 : 1.0)
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
                        let merchantParam: String? = (type == .income)
                            ? "Income"
                            : (merchant.isEmpty ? nil : merchant)

                        // Ensure category is Income when type is income
                        let finalCategory: ExpenseCategory = (type == .income) ? .income : category

                        onSave(
                            merchantParam,
                            amount.isEmpty ? nil : amount,
                            date,
                            type,
                            finalCategory,
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
            // Reactively force category to .income when switching to income
            .onChange(of: type) { newValue in
                if newValue == .income {
                    category = .income
                }
            }
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

