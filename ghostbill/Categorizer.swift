//
//  Categorizer.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-11.
//

import Foundation

// MARK: - Canonical categories

enum ExpenseCategory: String, CaseIterable, Codable {
    case groceries
    case coffee
    case dining
    case transport
    case fuel
    case shopping
    case utilities
    case housing
    case entertainment
    case travel
    case other
}

struct CategorySuggestion: Codable {
    let category: ExpenseCategory
    /// 0–10 rough confidence. >=7 strong, 4–6 medium, <4 low (use .other or ask user).
    let confidence: Int
}

// MARK: - Categorizer

final class Categorizer {
    static let shared = Categorizer()
    private init() { loadOverrides() }

    // MARK: Public API

    func suggestCategory(merchant: String?, rawText: String) -> CategorySuggestion {
        let normMerchant = normalizeMerchant(merchant ?? "")
        if let override = override(for: normMerchant) {
            return CategorySuggestion(category: override, confidence: 10)
        }

        // Base scores per category
        var scores = Dictionary(uniqueKeysWithValues: ExpenseCategory.allCases.map { ($0, 0) })

        // 1) Merchant-based scoring (exact + fuzzy)
        if !normMerchant.isEmpty {
            addMerchantScores(for: normMerchant, into: &scores)
        }

        // 2) Keyword scoring from receipt text
        addKeywordScores(from: rawText, into: &scores)

        // 3) Format cues (e.g., Dining includes tip)
        addFormatCueScores(from: rawText, into: &scores)

        // 4) Tie-breaking and category-specific precedence
        applyTieBreakers(from: rawText, normMerchant: normMerchant, scores: &scores)

        // Decide
        let (bestCategory, bestScore) = scores.max(by: { $0.value < $1.value }) ?? (.other, 0)

        // Thresholding: if too weak, call it .other
        let threshold = 4
        if bestScore < threshold {
            return CategorySuggestion(category: .other, confidence: bestScore.clamped(to: 0...3))
        }

        // Map score to confidence 0..10 (cap)
        let confidence = min(10, bestScore)
        return CategorySuggestion(category: bestCategory, confidence: confidence)
    }

    func remember(merchant raw: String, as category: ExpenseCategory) {
        let normalized = normalizeMerchant(raw)
        guard !normalized.isEmpty else { return }
        overrides[normalized] = category
        saveOverrides()
    }

    // MARK: - Normalization

    func normalizeMerchant(_ s: String) -> String {
        var out = s.lowercased()
        // Remove diacritics
        out = out.folding(options: .diacriticInsensitive, locale: .current)

        // Replace punctuation (except & and +) with space
        out = out.replacingOccurrences(of: #"[^a-z0-9&+ ]"#, with: " ", options: .regularExpression)

        // Remove trailing store/unit IDs (e.g., "#1234", "no. 12", "store 7038", "unit 214", "- 7038")
        out = out.replacingOccurrences(of: #"(?:^|\s)(?:store|unit|no\.?|#)\s*\d+\b"#, with: "", options: .regularExpression)
        out = out.replacingOccurrences(of: #"\b\d{3,6}\b$"#, with: "", options: .regularExpression)

        // Collapse repeated spaces
        out = out.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Merchant scoring

    private func addMerchantScores(for merchant: String, into scores: inout [ExpenseCategory: Int]) {
        // Exact dictionary hits
        for (cat, names) in merchantSeeds {
            if names.contains(merchant) {
                scores[cat, default: 0] += 10 // strong exact hit
            }
        }

        // Fuzzy hits (tolerate small OCR errors)
        for (cat, names) in merchantSeeds {
            for name in names where name != merchant {
                if fuzzyMatch(merchant, name) {
                    scores[cat, default: 0] += 7 // fuzzy but strong
                    break
                }
            }
        }

        // Generic cues in merchant string
        for (cat, tokens) in merchantCues {
            if tokens.contains(where: { merchant.contains($0) }) {
                scores[cat, default: 0] += 4
            }
        }
    }

    // MARK: - Keyword scoring

    private func addKeywordScores(from text: String, into scores: inout [ExpenseCategory: Int]) {
        let lower = text.lowercased()
        for (cat, tokens) in textTokens {
            var hits = 0
            for t in tokens {
                if lower.contains(t) { hits += 1 }
            }
            if hits > 0 {
                // Cap token contribution to avoid swamping
                scores[cat, default: 0] += min(8, hits * 2)
            }
        }
    }

    // MARK: - Format cues

    private func addFormatCueScores(from text: String, into scores: inout [ExpenseCategory: Int]) {
        let lower = text.lowercased()

        // Dining often shows tip lines
        if lower.contains("tip") || lower.contains("gratuity") {
            scores[.dining, default: 0] += 4
        }

        // Fuel-specific numeric cues
        if lower.range(of: #"\b(litre|liter|gallon|octane|diesel|unleaded|pump|kwh)\b"#, options: .regularExpression) != nil {
            scores[.fuel, default: 0] += 4
        }

        // Utilities bill cues
        if lower.contains("billing period") || lower.contains("account number") || lower.contains("statement") ||
            lower.range(of: #"\b(kwh|gb|min|data)\b"#, options: .regularExpression) != nil {
            scores[.utilities, default: 0] += 4
        }

        // Travel cues
        if lower.contains("boarding") || lower.contains("gate ") || lower.contains("flight") ||
            lower.contains("reservation") || lower.contains("check-in") || lower.contains("check in") ||
            lower.contains("baggage") {
            scores[.travel, default: 0] += 4
        }

        // Groceries cue: lots of line items + weights/SKUs
        let skuLike = lower.components(separatedBy: .newlines)
            .filter { $0.range(of: #"\bkg\b|\blb\b|\bsku\b"#, options: .regularExpression) != nil }
            .count
        if skuLike >= 2 {
            scores[.groceries, default: 0] += 3
        }
    }

    // MARK: - Tie breakers / precedence

    private func applyTieBreakers(from text: String, normMerchant: String, scores: inout [ExpenseCategory: Int]) {
        let lower = text.lowercased()

        // Coffee vs Dining: prefer Coffee if coffee tokens present
        let coffeeTokens = ["espresso","latte","americano","cappuccino","mocha","macchiato","flat white","frappuccino","cold brew","drip"]
        if coffeeTokens.contains(where: { lower.contains($0) }) {
            scores[.coffee, default: 0] += 2
        }

        // Fuel vs Transport
        if lower.range(of: #"\b(litre|liter|gallon|octane|diesel|unleaded|pump|kwh)\b"#, options: .regularExpression) != nil {
            scores[.fuel, default: 0] += 1
        } else if lower.range(of: #"\b(ride|trip|fare|parking|toll|metro|bus|train)\b"#, options: .regularExpression) != nil {
            scores[.transport, default: 0] += 1
        }

        // Airlines/Hotels strongly pull to Travel
        if normMerchant.containsAny(of: travelStrongMerchants) {
            scores[.travel, default: 0] += 5
        }
    }

    // MARK: - Overrides persistence

    private let overridesKey = "CategorizerOverrides.v1"
    private var overrides: [String: ExpenseCategory] = [:]

    private func override(for normalizedMerchant: String) -> ExpenseCategory? {
        overrides[normalizedMerchant]
    }

    private func loadOverrides() {
        guard let data = UserDefaults.standard.data(forKey: overridesKey),
              let decoded = try? JSONDecoder().decode([String: ExpenseCategory].self, from: data) else { return }
        overrides = decoded
    }

    private func saveOverrides() {
        if let data = try? JSONEncoder().encode(overrides) {
            UserDefaults.standard.set(data, forKey: overridesKey)
        }
    }

    // MARK: - Fuzzy matching

    /// Quick fuzzy: substring OR Levenshtein distance within small threshold.
    private func fuzzyMatch(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        if a.contains(b) || b.contains(a) { return true }
        // Distance threshold based on length
        let dist = levenshtein(a, b)
        let limit = max(1, min(3, max(a.count, b.count) / 6))
        return dist <= limit
    }

    /// Simple Levenshtein distance
    private func levenshtein(_ aStr: String, _ bStr: String) -> Int {
        let a = Array(aStr)
        let b = Array(bStr)
        let n = a.count, m = b.count
        if n == 0 { return m }
        if m == 0 { return n }

        var prev = Array(0...m)
        var curr = Array(repeating: 0, count: m + 1)

        for i in 1...n {
            curr[0] = i
            for j in 1...m {
                let cost = (a[i-1] == b[j-1]) ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,      // deletion
                    curr[j-1] + 1,    // insertion
                    prev[j-1] + cost  // substitution
                )
            }
            swap(&prev, &curr)
        }
        return prev[m]
    }

    // MARK: - Seeds & tokens (stored with explicit types)

    /// Exact normalized merchant names by category (add over time)
    private let merchantSeeds: [ExpenseCategory: Set<String>] = [
        .coffee: Set([
            "starbucks","tim hortons","dunkin","blue bottle","philz coffee","peet s coffee","blenz coffee","jj bean","caffe nero"
        ]),
        .dining: Set([
            "mcdonald s","chipotle","subway","pizza hut","domino s","kfc","five guys","sweetgreen","earls","cactus club","joey","nando s","poke","sushi"
        ]),
        .groceries: Set([
            "whole foods","safeway","trader joe s","no frills","loblaws","real canadian superstore","save on foods","iga","walmart supercentre","costco wholesale"
        ]),
        .fuel: Set([
            "shell","chevron","petro canada","esso","mobil","bp","76","circle k","chargepoint","evgo","electrify america"
        ]),
        .transport: Set([
            "uber","lyft","yellow cab","bc transit","translink","compass","via rail","amtrak","paybyphone","parkmobile","zipcar"
        ]),
        .shopping: Set([
            "amazon","best buy","walmart","target","apple store","microsoft store","ikea","home depot","canadian tire","sport chek","sunglass hut","zara","h m","uniqlo"
        ]),
        .utilities: Set([
            "xfinity","comcast","verizon","t mobile","at t","rogers","bell","telus","shaw","hydro one","bc hydro","fortisbc","enbridge"
        ]),
        .housing: Set([
            "airbnb","hoa","strata","property management","landlord","rent payment","mortgage"
        ]),
        .entertainment: Set([
            "amc","cinemark","cineplex","ticketmaster","stubhub","netflix","spotify","disney","playstation","xbox","steam"
        ]),
        .travel: Set([
            "delta","united","air canada","westjet","alaska airlines","american airlines","marriott","hilton","hyatt","ihg","hertz","avis","budget","enterprise"
        ]),
        .other: Set([])
    ]

    /// Merchant string cues (contained tokens) by category
    private let merchantCues: [ExpenseCategory: [String]] = [
        .coffee: ["coffee","cafe","caff","espresso","roasters"],
        .dining: ["grill","bistro","restaurant","kitchen","bar","pizza","sushi","burger","noodle","ramen","taco"],
        .groceries: ["market","grocery","foods","supermarket","produce"],
        .fuel: ["gas","fuel","petro","oil","station","charge"],
        .transport: ["taxi","cab","transit","metro","bus","train","parking","park"],
        .shopping: ["store","shop","outlet","mart","depot"],
        .utilities: ["hydro","power","electric","water","gas","internet","mobile","cell","wireless"],
        .housing: ["rent","hoa","strata","property","management","mortgage"],
        .entertainment: ["cinema","theatre","theater","ticket","concert","stream","arcade"],
        .travel: ["air","hotel","inn","hostel","car rental","rent a car","lodge"]
    ]

    /// Text tokens by category
    private let textTokens: [ExpenseCategory: [String]] = [
        .coffee: ["latte","espresso","americano","cappuccino","mocha","macchiato","frappuccino","cold brew","drip","flat white"],
        .dining: ["tip","gratuity","table","server","dine in","takeout"],
        .groceries: ["produce","bakery","deli","meat","seafood","grocery","receipt subtotal"],
        .fuel: ["litre","liter","gallon","octane","diesel","unleaded","pump","kwh"],
        .transport: ["ride","trip","fare","parking","toll","metro","bus","train","ticket"],
        .shopping: ["sku","warranty","electronics","apparel","size","model"],
        .utilities: ["billing period","account number","statement","kwh","gb","minutes","usage","service address"],
        .housing: ["rent","lease","unit","suite","maintenance","hoa","strata","due date"],
        .entertainment: ["ticket","showtime","subscription","pass","season","seat","row"],
        .travel: ["flight","boarding","gate","pnr","airline","reservation","hotel","room","check-in","baggage","itinerary"],
        .other: []
    ]

    private let travelStrongMerchants: [String] = [
        "air canada","westjet","delta","united","american airlines","alaska airlines",
        "marriott","hilton","hyatt","ihg","hertz","avis","budget","enterprise"
    ]
}

// MARK: - Small helpers

private extension String {
    func containsAny(of tokens: [String]) -> Bool {
        tokens.contains(where: { self.contains($0) })
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

