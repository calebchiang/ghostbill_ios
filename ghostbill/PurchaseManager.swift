//
//  PurchaseManager.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-19.
//

import Foundation
import RevenueCat

@MainActor
final class PurchaseManager: ObservableObject {
    static let monthlyId = "monthly"
    static let annualId  = "annual"

    private enum ProductID {
        static let monthly = "com.ghostbill.subscription.monthly"
        static let yearly  = "com.ghostbill.subscription.yearly"
    }

    @Published var userId: UUID?
    @Published private(set) var offerings: Offerings?
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    func setUser(id: UUID) { self.userId = id }

    func start() { refreshOfferings() }

    func refreshOfferings() {
        isLoading = true
        lastError = nil
        Purchases.shared.getOfferings { [weak self] offerings, error in
            guard let self else { return }
            Task { @MainActor in
                self.isLoading = false
                if let error { self.lastError = error.localizedDescription }
                self.offerings = offerings
            }
        }
    }

    var monthlyPackage: Package? {
        if let p = package(matchingProductID: ProductID.monthly) { return p }
        if let p = offerings?.current?.package(identifier: Self.monthlyId) { return p }
        if let p = offerings?.current?.monthly { return p }
        return offerings?.current?.availablePackages.first { $0.packageType == .monthly }
    }

    var annualPackage: Package? {
        if let p = package(matchingProductID: ProductID.yearly) { return p }
        if let p = offerings?.current?.package(identifier: Self.annualId) { return p }
        if let p = offerings?.current?.annual { return p }
        return offerings?.current?.availablePackages.first { $0.packageType == .annual }
    }

    private func package(matchingProductID id: String) -> Package? {
        offerings?.current?.availablePackages.first { $0.storeProduct.productIdentifier == id }
    }

    enum PurchaseResult { case success, cancelled, failure(Error) }

    func purchase(package: Package, completion: @escaping (PurchaseResult) -> Void) {
        Purchases.shared.purchase(package: package) { [weak self] _, _, error, userCancelled in
            guard let self else { return }
            if userCancelled { completion(.cancelled); return }
            if let error { completion(.failure(error)); return }

            if let uid = self.userId {
                let pid = package.storeProduct.productIdentifier
                Task {
                    do {
                        if pid == ProductID.yearly {
                            try await ProfilesService.shared.setYearlyActive(userId: uid)
                        } else if pid == ProductID.monthly {
                            try await ProfilesService.shared.setMonthlyActive(userId: uid)
                        } else {
                            await self.applyCustomerInfoAndUpdateBackend(userId: uid)
                        }
                    } catch {
                        self.lastError = "Failed to update plan: \(error.localizedDescription)"
                    }
                }
            }
            completion(.success)
        }
    }

    func restore(completion: @escaping (PurchaseResult) -> Void) {
        Purchases.shared.restorePurchases { [weak self] _, error in
            guard let self else { return }
            if let error { completion(.failure(error)); return }
            if let uid = self.userId {
                Task { await self.applyCustomerInfoAndUpdateBackend(userId: uid) }
            }
            completion(.success)
        }
    }

    private func applyCustomerInfoAndUpdateBackend(userId: UUID) async {
        do {
            let info = try await Purchases.shared.customerInfo()
            let active = info.activeSubscriptions
            if active.contains(ProductID.yearly) {
                try await ProfilesService.shared.setYearlyActive(userId: userId)
            } else if active.contains(ProductID.monthly) {
                try await ProfilesService.shared.setMonthlyActive(userId: userId)
            } else {
                try await ProfilesService.shared.setFree(userId: userId)
            }
        } catch {
            self.lastError = "Failed to sync subscription status: \(error.localizedDescription)"
        }
    }

    func priceString(for package: Package) -> String {
        package.storeProduct.localizedPriceString
    }

    func debugPrintPackages() {
        guard let offering = offerings?.current else {
            print("RC: No current offering.")
            return
        }
        print("RC: current offering = \(offering.identifier), packages=\(offering.availablePackages.count)")
        for p in offering.availablePackages {
            print("- pkg.id=\(p.identifier), type=\(p.packageType.rawValue), productID=\(p.storeProduct.productIdentifier), price=\(p.storeProduct.localizedPriceString)")
        }
    }
}

