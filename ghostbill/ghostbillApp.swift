//
//  ghostbillApp.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-09.
//

import SwiftUI
import Supabase
import RevenueCat

@main
struct ghostbillApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var purchases: PurchaseManager

    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif

        let rcKey = AppConfig.revenueCatPublicSDKKey
        assert(!rcKey.isEmpty, "Missing RC_PUBLIC_KEY in Config.plist")
        Purchases.configure(withAPIKey: rcKey)
        let manager = PurchaseManager()
        _purchases = StateObject(wrappedValue: manager)
        manager.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(purchases)
                .environment(\.supabaseClient, SupabaseManager.shared.client)
                .onOpenURL { url in
                    Task {
                        do {
                            _ = try await SupabaseManager.shared.client.auth.session(from: url)
                        } catch {
                            print("Auth callback error: \(error)")
                        }
                    }
                }
        }
    }
}

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: AppConfig.supabaseURL)!,
            supabaseKey: AppConfig.supabaseAnonKey
        )
    }
}

private struct SupabaseClientKey: EnvironmentKey {
    static let defaultValue: SupabaseClient = SupabaseManager.shared.client
}

extension EnvironmentValues {
    var supabaseClient: SupabaseClient {
        get { self[SupabaseClientKey.self] }
        set { self[SupabaseClientKey.self] = newValue }
    }
}

