//
//  TransactionView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-13.
//

import SwiftUI
import Supabase

struct TransactionView: View {
    // Input
    let transaction: DBTransaction
    var onUpdated: (DBTransaction) -> Void
    var onDeleted: (UUID) -> Void

    // Local copy we can update after edits
    @State private var tx: DBTransaction

    // Edit state
    @State private var isEditing = false
    @State private var formMerchant: String = ""
    @State private var formAmount: String = ""
    @State private var formDate: Date = Date()
    @State private var formCategory: ExpenseCategory = .other
    @State private var formNotes: String = ""

    // UI state
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var showDeleteConfirm = false

    // Palette (match app)
    private let bg        = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let cardBG    = Color(red: 0.14, green: 0.14, blue: 0.17)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let stroke    = Color.white.opacity(0.06)
    private let indigo    = Color(red: 0.31, green: 0.27, blue: 0.90)

    @Environment(\.dismiss) private var dismiss

    init(
        transaction: DBTransaction,
        onUpdated: @escaping (DBTransaction) -> Void = { _ in },
        onDeleted: @escaping (UUID) -> Void = { _ in }
    ) {
        self.transaction = transaction
        self.onUpdated = onUpdated
        self.onDeleted = onDeleted
        _tx = State(initialValue: transaction)
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if let errorText {
                        Text(errorText)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .padding(.horizontal, 16)
                    }

                    if isEditing {
                        editCard   // no header card in edit mode
                    } else {
                        headerCard
                        detailsCard
                        notesCard
                    }
                }
                .padding(16)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isEditing {
                    Button("Edit") {
                        seedForm(from: tx)
                        withAnimation(.easeInOut) { isEditing = true }
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isSaving)
        .confirmationDialog(
            "Remove this expense?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Transaction", role: .destructive) {
                Task { await deleteTapped() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Cards (Read Mode)

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(formatAmountDisplay(tx.amount))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(tx.amount < 0 ? .red : .green)

                Spacer()

                CategoryBadge(category: tx.categoryEnum)
            }

            Text(tx.merchant?.isEmpty == false ? (tx.merchant ?? "Unknown") : "Unknown")
                .foregroundColor(textLight)
                .font(.headline)

            Text(longDate(tx.date))
                .foregroundColor(textMuted)
                .font(.subheadline)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(cardBG))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(label: "Merchant", value: tx.merchant ?? "Unknown")
            divider
            row(label: "Category", value: tx.categoryEnum.displayName)
            divider
            row(label: "Date", value: longDate(tx.date))
            divider
            row(label: "Amount",
                value: formatAmountDisplay(tx.amount),
                valueColor: tx.amount < 0 ? .red : .green)
            divider
            row(label: "Currency", value: tx.currency)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(cardBG))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(stroke, lineWidth: 1))
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(textMuted)

            Text((tx.note?.isEmpty == false ? tx.note! : "No notes added."))
                .foregroundColor(textLight)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(cardBG))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(stroke, lineWidth: 1))
    }

    // MARK: - Edit UI

    private var editCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Edit Transaction")
                    .font(.title3.bold())
                    .foregroundColor(textLight)
                Spacer()
                // Red trash icon acts as remove button
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.red)
                        .accessibilityLabel("Remove Expense")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Merchant").foregroundColor(textMuted).font(.footnote)
                TextField("Enter merchant", text: $formMerchant)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(Color.black.opacity(0.25))
                    .cornerRadius(12)
                    .foregroundColor(textLight)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Amount (numbers only)").foregroundColor(textMuted).font(.footnote)
                HStack(spacing: 8) {
                    Text(tx.amount < 0 ? "-" : "+")
                        .foregroundColor(textMuted)
                    Text("$")
                        .foregroundColor(textMuted)
                    TextField("0.00", text: $formAmount)
                        .keyboardType(.decimalPad)
                        .foregroundColor(textLight)
                }
                .padding(12)
                .background(Color.black.opacity(0.25))
                .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Date").foregroundColor(textMuted).font(.footnote)
                DatePicker("", selection: $formDate, displayedComponents: .date)
                    .labelsHidden()
                    .padding(12)
                    .background(Color.black.opacity(0.25))
                    .cornerRadius(12)
                    .colorScheme(.dark)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Category").foregroundColor(textMuted).font(.footnote)
                Picker("Select category", selection: $formCategory) {
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
                TextField("Optional", text: $formNotes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .padding(12)
                    .background(Color.black.opacity(0.25))
                    .cornerRadius(12)
                    .foregroundColor(textLight)
            }

            // Actions
            VStack(spacing: 10) {
                Button {
                    Task { await updateTapped() }
                } label: {
                    HStack {
                        if isSaving { ProgressView().tint(.white) }
                        Text(isSaving ? "Updating..." : "Update")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(indigo)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .disabled(isSaving)

                Button {
                    withAnimation(.easeInOut) { isEditing = false }
                    errorText = nil
                } label: {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundColor(textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(12)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(cardBG))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(stroke, lineWidth: 1))
    }

    // MARK: - Pieces

    private func row(label: String, value: String, valueColor: Color? = nil, monospaced: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundColor(textMuted)
                .font(.subheadline)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(valueColor ?? textLight)
                .textSelection(.enabled)
                .if(monospaced) { $0.monospaced() } // iOS 16-safe
        }
        .padding(.vertical, 10)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }

    // MARK: - Actions

    private func seedForm(from t: DBTransaction) {
        formMerchant = t.merchant ?? ""
        formAmount   = String(format: "%.2f", abs(t.amount))
        formDate     = t.date
        formCategory = t.categoryEnum
        formNotes    = t.note ?? ""
    }

    private func updateTapped() async {
        errorText = nil
        guard !isSaving else { return }

        guard let userId = try? await SupabaseManager.shared.client.auth.session.user.id else {
            errorText = "Not signed in."
            return
        }

        guard let raw = Double(formAmount.replacingOccurrences(of: ",", with: ".")) else {
            errorText = "Enter a valid amount."
            return
        }

        let signedAmount = (tx.amount < 0) ? -abs(raw) : abs(raw)

        isSaving = true
        do {
            let updated = try await TransactionsService.shared.updateTransaction(
                userId: userId,
                id: tx.id,
                amount: signedAmount,
                currency: nil,                 // unchanged
                date: formDate,
                merchant: formMerchant.isEmpty ? nil : formMerchant,
                category: formCategory,
                note: formNotes.isEmpty ? nil : formNotes
            )
            tx = updated
            onUpdated(updated)                 // 👉 notify parent list
            withAnimation(.easeInOut) { isEditing = false }
        } catch {
            errorText = error.localizedDescription
        }
        isSaving = false
    }

    private func deleteTapped() async {
        errorText = nil
        guard let userId = try? await SupabaseManager.shared.client.auth.session.user.id else {
            errorText = "Not signed in."
            return
        }
        isSaving = true
        do {
            _ = try await TransactionsService.shared.deleteTransaction(userId: userId, id: tx.id)
            onDeleted(tx.id)                   // 👉 notify parent list
            dismiss()                          // pop back after delete
        } catch {
            errorText = error.localizedDescription
        }
        isSaving = false
    }

    // MARK: - Formatting

    /// Display like +$12.34 or -$45.67 (no currency code in the string).
    private func formatAmountDisplay(_ amount: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencySymbol = "$"
        nf.currencyCode = "" // do not append code
        nf.maximumFractionDigits = 2
        nf.minimumFractionDigits = 0

        let sign = amount < 0 ? "-" : "+"
        let absStr = nf.string(from: NSNumber(value: abs(amount))) ?? "$\(abs(amount))"
        return "\(sign)\(absStr)"
    }

    private func longDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMMM d, yyyy"
        return df.string(from: date)
    }
}

// MARK: - Pretty names for categories
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

// MARK: - View helpers

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TransactionView_Previews: PreviewProvider {
    static var previews: some View {
        let sample = DBTransaction(
            id: UUID(),
            user_id: UUID(),
            amount: -46.18,
            currency: "USD",
            date: Date(),
            merchant: "Netflix",
            category: "entertainment",
            note: "September subscription",
            created_at: Date(),
            updated_at: Date()
        )

        NavigationStack {
            TransactionView(transaction: sample)
        }
        .preferredColorScheme(.dark)
    }
}
#endif

