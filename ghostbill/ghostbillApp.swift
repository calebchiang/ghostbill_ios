//
//  ghostbillApp.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-09.
//

import SwiftUI
import Supabase

@main
struct ghostbillApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
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

