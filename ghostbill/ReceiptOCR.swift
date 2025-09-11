//
//  ReceiptOCR.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-11.
//

import Foundation
import Vision
import UIKit

struct OCRResult {
    var merchant: String?
    var amount: String?
    var date: Date?
    var category: ExpenseCategory
    var categoryConfidence: Int
    var rawText: String
}

enum ReceiptOCRError: Error { case imageFailure, recognitionFailure }

final class ReceiptOCR {
    static let shared = ReceiptOCR()

    func extract(from image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.fixedOrientation().cgImage else { throw ReceiptOCRError.imageFailure }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en_US"]
        if #available(iOS 16.0, *) {
            request.revision = VNRecognizeTextRequestRevision3
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.vnOrientation, options: [:])
        try handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else {
            throw ReceiptOCRError.recognitionFailure
        }

        let lines: [String] = observations.compactMap { $0.topCandidates(1).first?.string }
        let trimmedLines = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let raw = trimmedLines.joined(separator: "\n")

        let amount = extractAmount(from: raw)
        let date = extractDate(from: raw)

        // Extract merchant line
        var merchant = extractMerchant(fromLines: trimmedLines)

        // Autocorrect to canonical brand name when possible
        if let m = merchant,
           let fix = MerchantLexicon.shared.autocorrectDisplayName(for: m) {
            merchant = fix.name
        }

        // Category suggestion (use corrected merchant)
        let suggestion = Categorizer.shared.suggestCategory(merchant: merchant, rawText: raw)

        return OCRResult(
            merchant: merchant,
            amount: amount,
            date: date,
            category: suggestion.category,
            categoryConfidence: suggestion.confidence,
            rawText: raw
        )
    }

    // MARK: - Parsing helpers

    private func extractAmount(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        let moneyPattern = #"\$?\s*\d{1,3}(?:,\d{3})*(?:\.\d{2})"#
        let totalKeywords = ["total cad", "grand total", "amount due", "balance", "total"]
        let isRefundReceipt = text.lowercased().contains("refund") || text.lowercased().contains("return")

        // --- NEW: Prefer the biggest value immediately after the last "total" label (same line + next 6 lines)
        let lowerLines = lines.map { $0.lowercased() }
        if let lastTotalIdx = lowerLines.indices.reversed().first(where: { idx in
            totalKeywords.contains(where: { lowerLines[idx].contains($0) })
        }) {
            let moneyRegex = try? NSRegularExpression(pattern: moneyPattern)
            let endIdx = min(lines.count - 1, lastTotalIdx + 6)
            var windowValues: [Double] = []

            for i in lastTotalIdx...endIdx {
                let raw = lines[i] as NSString
                let matches = moneyRegex?.matches(in: lines[i], range: NSRange(location: 0, length: raw.length)) ?? []
                for m in matches {
                    var s = raw.substring(with: m.range)
                    s = s.replacingOccurrences(of: "$", with: "")
                         .replacingOccurrences(of: ",", with: "")
                         .replacingOccurrences(of: " ", with: "")
                    if let v = Double(s) {
                        windowValues.append(v)
                    }
                }
            }

            if let maxAfterTotal = windowValues.max() {
                return String(format: "%.2f", maxAfterTotal)
            }
        }

        var candidates: [(value: Double, score: Int)] = []

        for (i, raw) in lines.enumerated() {
            let lineLower = raw.lowercased()
            let regex = try? NSRegularExpression(pattern: moneyPattern)
            let ns = raw as NSString
            let matches = regex?.matches(in: raw, range: NSRange(location: 0, length: ns.length)) ?? []

            for m in matches {
                var s = ns.substring(with: m.range)
                let original = s
                let isNegative = raw.contains("(\(original))") || raw.contains("(\(original.replacingOccurrences(of: "$", with: "")))")

                s = s.replacingOccurrences(of: "$", with: "")
                     .replacingOccurrences(of: ",", with: "")
                     .replacingOccurrences(of: " ", with: "")

                guard let v = Double(s) else { continue }

                var score = 0
                if totalKeywords.contains(where: { lineLower.contains($0) }) { score += 8 }
                if i > 0 && totalKeywords.contains(where: { lines[i-1].lowercased().contains($0) }) { score += 5 }
                if i + 1 < lines.count && totalKeywords.contains(where: { lines[i+1].lowercased().contains($0) }) { score += 5 }
                if isNegative && !isRefundReceipt { score -= 10 }
                score += min(i / 5, 6)

                candidates.append((v, score))
            }
        }

        if let best = candidates.max(by: { lhs, rhs in
            lhs.score == rhs.score ? lhs.value < rhs.value : lhs.score < rhs.score
        }) {
            return String(format: "%.2f", best.value)
        }

        let fallbackRegex = try? NSRegularExpression(pattern: moneyPattern)
        let ns = text as NSString
        let ms = fallbackRegex?.matches(in: text, range: NSRange(location: 0, length: ns.length)) ?? []
        let positives = ms.compactMap { m -> Double? in
            var s = ns.substring(with: m.range)
            s = s.replacingOccurrences(of: "$", with: "")
                 .replacingOccurrences(of: ",", with: "")
                 .replacingOccurrences(of: " ", with: "")
            return Double(s)
        }.filter { $0 >= 0 }

        if let maxVal = positives.max() {
            return String(format: "%.2f", maxVal)
        }
        return nil
    }


    private func extractDate(from text: String) -> Date? {
        // 1) Prefer explicit 4-digit-year numeric formats
        let fourDigitPatterns = [
            #"\b(0?\d)[/-](0?\d)[/-](20\d{2})\b"#,
            #"\b(0?\d)[.](0?\d)[.](20\d{2})\b"#,
            #"\b(20\d{2})[/-](0?\d)[/-](0?\d)\b"#
        ]
        for p in fourDigitPatterns {
            if let date = firstDateMatch(in: text, regex: p, formats: ["MM/dd/yyyy","M/d/yyyy","MM-dd-yyyy","M-d-yyyy","MM.dd.yyyy","M.d.yyyy","yyyy/MM/dd","yyyy-MM-dd"]) {
                return date
            }
        }

        // 2) Month name formats
        let monthNamePatterns = [
            #"\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?\s+\d{1,2},\s+20\d{2}\b"#,
            #"\b\d{1,2}\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?\s+20\d{2}\b"#
        ]
        for p in monthNamePatterns {
            if let date = firstDateMatch(in: text, regex: p, formats: ["MMM d, yyyy","d MMM yyyy"]) {
                return date
            }
        }

        // 3) Two-digit year numeric formats
        let twoDigitPatterns = [
            #"\b(\d{1,2})[/-](\d{1,2})[/-](\d{2})\b"#,
            #"\b(\d{2})[/-](\d{1,2})[/-](\d{1,2})\b"#
        ]
        for p in twoDigitPatterns {
            if let date = firstDateMatchTwoDigitYear(in: text, regex: p) {
                return date
            }
        }

        // 4) Fallback to NSDataDetector
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let ns = text as NSString
            let range = NSRange(location: 0, length: ns.length)
            let matches = detector.matches(in: text, options: [], range: range)
            if let date = matches.first?.date {
                return date
            }
        }

        return nil
    }

    private func firstDateMatch(in text: String, regex: String, formats: [String]) -> Date? {
        guard let re = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = re.firstMatch(in: text, options: [], range: range) else { return nil }
        let s = ns.substring(with: match.range)

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in formats {
            df.dateFormat = fmt
            if let d = df.date(from: s) { return d }
        }
        return nil
    }

    private func firstDateMatchTwoDigitYear(in text: String, regex: String) -> Date? {
        guard let re = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = re.firstMatch(in: text, options: [], range: range) else { return nil }
        let s = ns.substring(with: match.range)

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")

        func parse(_ fmt: String) -> Date? {
            df.dateFormat = fmt
            guard var d = df.date(from: s) else { return nil }
            // Force year into 2000–2099 if needed
            let cal = Calendar.current
            var comps = cal.dateComponents([.year,.month,.day], from: d)
            if let y = comps.year, y < 2000 {
                comps.year = 2000 + (y % 100)
                d = cal.date(from: comps) ?? d
            }
            return d
        }

        let tokens = s.split(whereSeparator: { "/-".contains($0) }).compactMap { Int($0) }
        if tokens.count == 3 {
            let a = tokens[0], b = tokens[1]
            if a > 12 { return parse("dd/MM/yy") }
            if b > 12 { return parse("MM/dd/yy") }
        }

        if let d1 = parse("MM/dd/yy") { return d1 }
        if let d2 = parse("dd/MM/yy") { return d2 }
        if let d3 = parse("yy/MM/dd") { return d3 }
        if let d4 = parse("yy-MM-dd") { return d4 }
        if let d5 = parse("dd-MM-yy") { return d5 }
        if let d6 = parse("dd.MM.yy") { return d6 }

        return nil
    }

    private func fourDigitYearHint(in text: String) -> Int? {
        let re = try? NSRegularExpression(pattern: #"\b(20\d{2})\b"#, options: [])
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        if let m = re?.firstMatch(in: text, options: [], range: range) {
            let s = ns.substring(with: m.range(at: 1))
            return Int(s)
        }
        return nil
    }

    // MARK: - Merchant extraction (scored)
    private func extractMerchant(fromLines lines: [String]) -> String? {
        if lines.isEmpty { return nil }

        let bannedKeywords = ["total","subtotal","tax","gst","pst","hst","visa","mastercard","debit","credit","change","cash","approval","auth","receipt","transaction","account","card","thank","order","item","qty","store","register","cashier","salesperson","invoice","terminal","merchant #","auth #","ref #","resp","iso"]
        let noise = ["control option","menu","cancel","photo","video","camera","hdr","portrait","live"]
        func containsAny(_ s: String, _ arr: [String]) -> Bool { arr.contains(where: { s.contains($0) }) }

        func isAddress(_ s: String) -> Bool {
            s.range(of: #"\d{1,5}\s+\w+"#, options: .regularExpression) != nil ||
            s.range(of: #"[A-Z]{2}\s*\d{2,}"#, options: .regularExpression) != nil
        }
        func isPhone(_ s: String) -> Bool {
            s.range(of: #"\(?\d{3}\)?[-.\s]\d{3}[-.\s]\d{4}"#, options: .regularExpression) != nil
        }
        func hasEmailOrURL(_ s: String) -> Bool {
            s.contains("@") || s.range(of: #"https?://|www\."#, options: .regularExpression) != nil
        }
        func mostlyLetters(_ s: String) -> Bool {
            let letters = s.filter { $0.isLetter }.count
            return letters >= 3 && Double(letters) / Double(max(1, s.count)) > 0.6
        }
        func looksTitleCased(_ s: String) -> Bool {
            let words = s.split(separator: " ")
            guard !words.isEmpty else { return false }
            let capped = words.filter { w in
                guard let first = w.first else { return false }
                return String(first).uppercased() == String(first)
            }.count
            return Double(capped) / Double(words.count) >= 0.6
        }

        var candidates: [(line: String, score: Int)] = []
        let limit = min(lines.count, 25)

        for i in 0..<limit {
            let raw = lines[i]
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }

            let lower = line.lowercased()

            if containsAny(lower, noise) { continue }
            if containsAny(lower, bannedKeywords) { continue }
            if isAddress(line) || isPhone(line) || hasEmailOrURL(line) { continue }

            var score = 0
            score += max(0, 8 - i)

            let words = line.split(whereSeparator: { $0.isWhitespace })
            if (1...4).contains(words.count) { score += 3 }
            if mostlyLetters(line) { score += 3 }
            if looksTitleCased(line) { score += 2 }

            let digitCount = line.filter { $0.isNumber }.count
            if digitCount == 0 { score += 2 }
            else if digitCount <= 4 { /* no change */ }
            else { score -= 3 }

            candidates.append((line, score))
        }

        if let best = candidates.max(by: { $0.score < $1.score }) {
            return best.line
        }

        return lines.first
    }
}

// MARK: - UIImage helpers

private extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }

    var vnOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

