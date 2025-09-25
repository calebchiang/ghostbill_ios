//
//  ExportTransactionsView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-25.
//

import SwiftUI
import Supabase
import UniformTypeIdentifiers

struct ExportTransactionsView: View {
    enum ExportType: String, CaseIterable {
        case expenses = "Expenses only"
        case income = "Income only"
        case both = "Both"
    }

    enum DateMode: String {
        case all = "All transactions"
        case specificMonth = "Specific month"
    }

    var onSuccess: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    @State private var exportType: ExportType = .both
    @State private var dateMode: DateMode = .all

    @State private var months: [FilterTransactionsService.TxMonth] = []
    @State private var loadingMonths = false
    @State private var selectedMonth: Date? = nil

    @State private var isExporting = false
    @State private var exportDoc: CSVDocument?
    @State private var exportFilename: String = "transactions"

    private let bg = Color(red: 0.09, green: 0.09, blue: 0.11)
    private let textLight = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.80, green: 0.80, blue: 0.85)
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)
    private let card = Color(red: 0.14, green: 0.14, blue: 0.17)

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export to CSV")
                        .font(.title3).bold()
                        .foregroundColor(textLight)

                    // What to export
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What to export")
                            .foregroundColor(textMuted)
                            .font(.footnote)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            chip("Expenses only", isOn: exportType == .expenses) { exportType = .expenses }
                            chip("Income only", isOn: exportType == .income) { exportType = .income }
                            chip("Both", isOn: exportType == .both) { exportType = .both }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date range")
                            .foregroundColor(textMuted)
                            .font(.footnote)

                        HStack(spacing: 8) {
                            togglePill("All transactions", isOn: dateMode == .all) {
                                dateMode = .all
                            }
                            togglePill("Specific month", isOn: dateMode == .specificMonth) {
                                dateMode = .specificMonth
                                loadMonthsIfNeeded()
                            }
                        }

                        if dateMode == .specificMonth {
                            if loadingMonths {
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ], spacing: 12) {
                                    ForEach(0..<6, id: \.self) { _ in
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(card)
                                            .frame(height: 40)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                            )
                                            .redacted(reason: .placeholder)
                                    }
                                }
                            } else if months.isEmpty {
                                Text("No months found")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ], spacing: 12) {
                                    ForEach(months, id: \.id) { m in
                                        let isOn = selectedMonth == m.monthStart
                                        Button {
                                            if isOn {
                                                selectedMonth = nil
                                            } else {
                                                selectedMonth = m.monthStart
                                            }
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                                    .imageScale(.small)
                                                Text(shortMonthYear(m.monthStart))
                                                    .font(.subheadline)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.9)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 12)
                                            .background(Color.black.opacity(0.25))
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                            )
                                            .foregroundColor(textLight)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 8)

                // Actions
                VStack(spacing: 10) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundColor(textMuted)
                    }

                    Button {
                        Task { await export() }
                    } label: {
                        Text("Export")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(indigo)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .disabled(dateMode == .specificMonth && selectedMonth == nil)
                    .opacity((dateMode == .specificMonth && selectedMonth == nil) ? 0.6 : 1.0)
                }
            }
            .padding(16)
            .background(bg.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
        .fileExporter(
            isPresented: $isExporting,
            document: exportDoc,
            contentType: .commaSeparatedText,
            defaultFilename: exportFilename
        ) { result in
            // Clean up the temp document either way
            exportDoc = nil
            switch result {
            case .success:
                // Notify parent and close this sheet
                onSuccess("CSV successfully saved to Files.")
                dismiss()
            case .failure:
                // You could surface an error toast similarly if desired
                break
            }
        }
        .task {
            if dateMode == .specificMonth {
                loadMonthsIfNeeded()
            }
        }
    }

    // MARK: - UI helpers

    @ViewBuilder
    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .imageScale(.small)
                Text(title)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .foregroundColor(textLight)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func togglePill(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isOn ? Color.white.opacity(0.20) : Color.white.opacity(0.08))
                )
                .foregroundColor(textLight)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private func loadMonthsIfNeeded() {
        guard months.isEmpty, !loadingMonths else { return }
        Task {
            loadingMonths = true
            defer { loadingMonths = false }
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                let userId = session.user.id
                months = try await FilterTransactionsService.shared.getMonthsWithActivity(userId: userId)
            } catch {
                months = []
            }
        }
    }

    private func export() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id

            let kind: ExportTransactionsService.ExportKind = {
                switch exportType {
                case .expenses: return .expenses
                case .income:   return .income
                case .both:     return .both
                }
            }()

            let month = (dateMode == .specificMonth) ? selectedMonth : nil

            // Dynamic filename when a specific month is chosen
            if let m = month {
                let monthFormatter = DateFormatter()
                monthFormatter.locale = Locale(identifier: "en_US_POSIX")
                monthFormatter.dateFormat = "LLLL"
                let yearFormatter = DateFormatter()
                yearFormatter.locale = Locale(identifier: "en_US_POSIX")
                yearFormatter.dateFormat = "yyyy"

                let monthName = monthFormatter.string(from: m).lowercased()
                let year = yearFormatter.string(from: m)
                exportFilename = "transactions_\(monthName)_\(year)"
            } else {
                exportFilename = "transactions"
            }

            let rows = try await ExportTransactionsService.shared.fetchTransactionsForExport(
                userId: userId,
                kind: kind,
                monthDate: month
            )
            let data = ExportTransactionsService.shared.makeCSV(rows)
            exportDoc = CSVDocument(data: data)
            isExporting = true
        } catch {
            // Optionally bubble up an error toast via another callback
        }
    }

    private func shortMonthYear(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "LLL yyyy"
        return df.string(from: date)
    }
}

// MARK: - CSVDocument

private struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

