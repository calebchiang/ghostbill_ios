//
//  ExportTransactionsService.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-25.
//

import Foundation
import Supabase

struct ExportTransactionsService {
    enum ExportKind {
        case expenses
        case income
        case both
    }

    static let shared = ExportTransactionsService()
    private let client = SupabaseManager.shared.client

    private func monthBounds(for monthDate: Date, timezone: TimeZone) throws -> (start: Date, end: Date) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: monthDate)),
              let end = cal.date(byAdding: DateComponents(month: 1), to: start) else {
            throw NSError(domain: "ExportTransactionsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compute month bounds."])
        }
        return (start, end)
    }

    func fetchTransactionsForExport(
        userId: UUID,
        kind: ExportKind,
        monthDate: Date? = nil,
        timezone: TimeZone = .current
    ) async throws -> [DBTransaction] {
        var query = client
            .from("transactions")
            .select()
            .eq("user_id", value: userId)

        switch kind {
        case .income:
            query = query.eq("type", value: "income")
        case .expenses:
            query = query.neq("type", value: "income").lt("amount", value: 0)
        case .both:
            break
        }

        if let monthDate {
            let (start, end) = try monthBounds(for: monthDate, timezone: timezone)
            query = query.gte("date", value: start).lt("date", value: end)
        }

        let rows: [DBTransaction] = try await query
            .order("date", ascending: false)
            .execute()
            .value

        return rows
    }

    func makeCSV(_ txs: [DBTransaction]) -> Data {
        // Removed "id" from export
        let header = ["date","merchant","category","amount","currency","note"]
        var lines: [String] = [header.joined(separator: ",")]

        // Format date as YYYY-MM-DD (no time/timezone)
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd"

        func esc(_ s: String?) -> String {
            guard let s = s else { return "" }
            let needsQuote = s.contains(",") || s.contains("\"") || s.contains("\n")
            let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
            return needsQuote ? "\"\(escaped)\"" : escaped
        }

        for t in txs {
            let cols: [String] = [
                esc(df.string(from: t.date)),
                esc(t.merchant),
                esc(t.category),
                esc(String(format: "%.2f", t.amount)),
                esc(t.currency),
                esc(t.note)
            ]
            lines.append(cols.joined(separator: ","))
        }

        // UTF-8 with BOM for better Excel compatibility
        let bom = Data([0xEF, 0xBB, 0xBF])
        let body = lines.joined(separator: "\n").data(using: .utf8) ?? Data()
        return bom + body
    }
}

