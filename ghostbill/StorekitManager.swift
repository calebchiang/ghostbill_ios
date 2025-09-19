//
//  StorekitManager.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-19.
//

import Foundation
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    // Your App Store Connect product IDs
    enum IDs: String, CaseIterable {
        case monthly = "com.ghostbill.subscription.monthly"
        case yearly  = "com.ghostbill.subscription.yearly"
    }

    @Published var productsByID: [String: Product] = [:]
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var purchasedProductIDs: Set<String> = []

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { await observeTransactionUpdates() }
    }

    deinit { updatesTask?.cancel() }

    // Call on app start or onAppear of the paywall
    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        lastError = nil
        do {
            let ids = IDs.allCases.map { $0.rawValue }
            let loaded = try await Product.products(for: ids)
            var map: [String: Product] = [:]
            for p in loaded { map[p.id] = p }
            productsByID = map
            await refreshEntitlements()
        } catch {
            lastError = "Failed to load products: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func product(for id: IDs) -> Product? {
        productsByID[id.rawValue]
    }

    /// Purchases a specific product ID if it has been fetched.
    @discardableResult
    func purchase(id: IDs) async -> Bool {
        lastError = nil
        guard let product = product(for: id) else {
            lastError = "Product not available yet. Try again in a moment."
            return false
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    func restore() async {
        lastError = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = "Restore failed: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        purchasedProductIDs.removeAll()
        for id in IDs.allCases.map({ $0.rawValue }) {
            if let latest = await Transaction.latest(for: id),
               case .verified(let t) = latest,
               t.revocationDate == nil, !t.isUpgraded {
                purchasedProductIDs.insert(id)
            }
        }
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            do {
                let t = try checkVerified(result)
                purchasedProductIDs.insert(t.productID)
                await t.finish()
            } catch {
                // ignore unverifiable
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified(_, let error):
            throw error ?? NSError(domain: "StoreKit", code: -1,
                                   userInfo: [NSLocalizedDescriptionKey: "Unverified transaction"])
        }
    }
}
