//
//  ReviewTransactionView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI

struct ReviewTransactionView: View {
    var onSave: (_ merchant: String?, _ amount: String?, _ date: Date?, _ category: ExpenseCategory?, _ notes: String?) -> Void
    var onScanAgain: () -> Void
    var onCancel: () -> Void

    @State private var merchant: String
    @State private var amount: String
    @State private var date: Date
    @State private var category: ExpenseCategory
    @State private var notes: String

    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    private enum Field { case merchant, amount, notes }
    @FocusState private var focusedField: Field?
    private let notesAnchorID = "notes_anchor"

    init(
        initialMerchant: String?,
        initialAmount: String?,
        initialDate: Date?,
        initialCategory: ExpenseCategory?,
        onSave: @escaping (_ merchant: String?, _ amount: String?, _ date: Date?, _ category: ExpenseCategory?, _ notes: String?) -> Void,
        onScanAgain: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onScanAgain = onScanAgain
        self.onCancel = onCancel

        _merchant = State(initialValue: initialMerchant ?? "")
        _amount   = State(initialValue: initialAmount ?? "")
        _date     = State(initialValue: initialDate ?? Date())
        _category = State(initialValue: initialCategory ?? .other)
        _notes    = State(initialValue: "")
    }

    var body: some View {
        NavigationView {
            ZStack {
                bg.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
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
                                        .focused($focusedField, equals: .merchant)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Amount").foregroundColor(textMuted).font(.footnote)
                                    TextField("0.00", text: $amount)
                                        .keyboardType(.decimalPad)
                                        .padding(12)
                                        .background(Color.black.opacity(0.25))
                                        .cornerRadius(12)
                                        .foregroundColor(textLight)
                                        .focused($focusedField, equals: .amount)
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

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Notes").foregroundColor(textMuted).font(.footnote)
                                    TextField("Optional", text: $notes, axis: .vertical)
                                        .lineLimit(3, reservesSpace: true)
                                        .padding(12)
                                        .background(Color.black.opacity(0.25))
                                        .cornerRadius(12)
                                        .foregroundColor(textLight)
                                        .focused($focusedField, equals: .notes)
                                        .id(notesAnchorID)
                                }
                            }

                            Spacer(minLength: 8)

                            VStack(spacing: 10) {
                                Button {
                                    onSave(
                                        merchant.isEmpty ? nil : merchant,
                                        amount.isEmpty ? nil : amount,
                                        date,
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
                    }
                    .onChange(of: focusedField) { newValue in
                        if newValue == .notes {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(notesAnchorID, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }
}

// Pretty names for the enum in the picker
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
        case .personal:      return "Personal"
        case .income:        return "Income"
        case .other:         return "Other"
        }
    }
}

