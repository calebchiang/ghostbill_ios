//
//  MerchantLexicon.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-11.
//

import Foundation

/// Single source of truth for merchant seeds + fuzzy autocorrection.
final class MerchantLexicon {

    static let shared = MerchantLexicon()

    /// Canonical (nice-cased) seeds by category.
    /// Add to these over time; categorizer and autocorrect both consume them.
    private let canonicalSeeds: [ExpenseCategory: [String]] = [
        .coffee: [
            "Starbucks","Tim Hortons","Dunkin","Blue Bottle","Philz Coffee","Peet's Coffee","Blenz Coffee","JJ Bean","Caffè Nero"
        ],
        .dining: [
            "McDonald's","Chipotle","Subway","Pizza Hut","Domino's","KFC","Five Guys","Sweetgreen","Earls","Cactus Club","JOEY","Nando's","Poke","Sushi"
        ],
        .groceries: [
            "Whole Foods","Safeway","Trader Joe's","No Frills","Loblaws","Real Canadian Superstore","Save-On-Foods","IGA","Walmart Supercentre","Costco Wholesale"
        ],
        .fuel: [
            "Shell","Chevron","Petro-Canada","Esso","Mobil","BP","76","Circle K","ChargePoint","EVgo","Electrify America"
        ],
        .transport: [
            "Uber","Lyft","Yellow Cab","BC Transit","TransLink","Compass","VIA Rail","Amtrak","PayByPhone","ParkMobile","Zipcar"
        ],
        .shopping: [
            "Amazon","Best Buy","Walmart","Target","Apple Store","Microsoft Store","IKEA","Home Depot","Canadian Tire","Sport Chek","Sunglass Hut","Zara","H&M","Uniqlo"
        ],
        .utilities: [
            "Xfinity","Comcast","Verizon","T-Mobile","AT&T","Rogers","Bell","Telus","Shaw","Hydro One","BC Hydro","FortisBC","Enbridge"
        ],
        .housing: [
            "Airbnb","HOA","Strata","Property Management","Landlord","Rent Payment","Mortgage"
        ],
        .entertainment: [
            "AMC","Cinemark","Cineplex","Ticketmaster","StubHub","Netflix","Spotify","Disney","PlayStation","Xbox","Steam"
        ],
        .travel: [
            "Delta","United","Air Canada","WestJet","Alaska Airlines","American Airlines","Marriott","Hilton","Hyatt","IHG","Hertz","Avis","Budget","Enterprise"
        ],
        .other: []
    ]

    /// Normalized -> Canonical display
    private(set) var canonicalByNormalized: [String: String] = [:]

    /// Category -> Set of normalized seed names
    private(set) var normalizedByCategory: [ExpenseCategory: Set<String>] = [:]

    /// Flat list of all normalized seeds
    private var allNormalizedSeeds: [String] = []

    /// User overrides (normalized input -> canonical display)
    private let overridesKey = "MerchantLexiconOverrides.v1"
    private var overrides: [String: String] = [:]

    private init() {
        // Build normalized maps from canonical seeds
        var tmpCat: [ExpenseCategory: Set<String>] = [:]
        var tmpCanon: [String: String] = [:]

        for (cat, list) in canonicalSeeds {
            var set = Set<String>()
            for display in list {
                let norm = Self.normalize(display)
                guard !norm.isEmpty else { continue }
                set.insert(norm)
                // If multiple display forms map to same norm, keep the "best" one (first is fine)
                if tmpCanon[norm] == nil {
                    tmpCanon[norm] = display
                }
            }
            tmpCat[cat] = set
        }

        normalizedByCategory = tmpCat
        canonicalByNormalized = tmpCanon
        allNormalizedSeeds = Array(tmpCanon.keys)

        loadOverrides()
    }

    // MARK: - Public API

    /// Returns a canonical display name and a 0–10 confidence, if we can confidently fix `raw`.
    func autocorrectDisplayName(for raw: String) -> (name: String, confidence: Int)? {
        let normalized = Self.normalize(raw)
        guard !normalized.isEmpty else { return nil }

        // User override beats everything
        if let fixed = overrides[normalized] {
            return (fixed, 10)
        }

        // Exact seed match
        if let exact = canonicalByNormalized[normalized] {
            return (exact, 10)
        }

        // Fuzzy against seeds (pre-filtered)
        let candidates = prefilterCandidates(for: normalized)
        guard !candidates.isEmpty else { return nil }

        var bestName: String?
        var bestScore: Double = 0

        for seed in candidates {
            let score = similarityScore(normalized, seed)
            if score > bestScore {
                bestScore = score
                bestName = seed
            }
        }

        guard let best = bestName, let display = canonicalByNormalized[best] else { return nil }

        // Accept only if over threshold
        let acceptThreshold = 0.82
        if bestScore >= acceptThreshold {
            return (display, Int(round(bestScore * 10)))
        }

        return nil
    }

    /// Remember the user’s correction permanently (normalized input -> canonical display).
    func remember(rawInput: String, asDisplay display: String) {
        let key = Self.normalize(rawInput)
        let value = display.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !value.isEmpty else { return }
        overrides[key] = value
        saveOverrides()
    }

    // MARK: - Normalization (shared rules)

    /// Lowercase, remove diacritics/punct, drop trailing store IDs, collapse spaces.
    static func normalize(_ s: String) -> String {
        var out = s.lowercased()
        out = out.folding(options: .diacriticInsensitive, locale: .current)
        out = out.replacingOccurrences(of: #"[^a-z0-9&+ ]"#, with: " ", options: .regularExpression)
        out = out.replacingOccurrences(of: #"(?:^|\s)(?:store|unit|no\.?|#)\s*\d+\b"#, with: "", options: .regularExpression)
        out = out.replacingOccurrences(of: #"\b\d{3,6}\b$"#, with: "", options: .regularExpression)
        out = out.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Internals

    private func prefilterCandidates(for norm: String) -> [String] {
        let tokens = Set(norm.split(separator: " ").map(String.init))
        guard !tokens.isEmpty else { return [] }

        return allNormalizedSeeds.filter { seed in
            let seedTokens = Set(seed.split(separator: " ").map(String.init))
            // must share at least one token
            guard !tokens.intersection(seedTokens).isEmpty else { return false }
            // length sanity (avoid super long vs short)
            let L = max(norm.count, seed.count)
            let S = min(norm.count, seed.count)
            return Double(S) / Double(L) >= 0.5
        }
    }

    /// Combined token-overlap + edit-distance similarity in [0,1].
    private func similarityScore(_ a: String, _ b: String) -> Double {
        if a == b { return 1.0 }

        let at = Set(a.split(separator: " ").map(String.init))
        let bt = Set(b.split(separator: " ").map(String.init))
        let inter = Double(at.intersection(bt).count)
        let union = Double(at.union(bt).count)
        let jaccard = union > 0 ? inter / union : 0

        let ld = Double(levenshtein(a, b))
        let edit = 1.0 - (ld / Double(max(1, max(a.count, b.count))))

        var score = 0.6 * jaccard + 0.4 * edit

        // small bonus for prefix alignment of the first token
        if let af = at.first, let bf = bt.first, af.prefix(3) == bf.prefix(3) {
            score += 0.03
        }
        return min(score, 1.0)
    }

    /// Levenshtein distance
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
                curr[j] = min(prev[j] + 1, curr[j-1] + 1, prev[j-1] + cost)
            }
            swap(&prev, &curr)
        }
        return prev[m]
    }

    // MARK: - Overrides persistence

    private func loadOverrides() {
        guard let data = UserDefaults.standard.data(forKey: overridesKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        overrides = decoded
    }

    private func saveOverrides() {
        if let data = try? JSONEncoder().encode(overrides) {
            UserDefaults.standard.set(data, forKey: overridesKey)
        }
    }
}
