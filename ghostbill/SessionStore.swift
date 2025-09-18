//
//  SessionStore.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import Foundation
import SwiftUI
import Supabase

@MainActor
final class SessionStore: ObservableObject {
    @Published var isAuthenticated: Bool = false

    private let client: SupabaseClient
    private var authListener: Any?
    private var authTask: Task<Void, Never>?

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
        Task { await loadInitialSession() }
        startAuthListener()
    }

    func signOut() {
        Task {
            do {
                try await client.auth.signOut()
            } catch {
                print("Sign out error: \(error)")
            }
        }
    }

    private func startAuthListener() {
        authTask?.cancel()
        authTask = Task { [weak self] in
            guard let self else { return }
            self.authListener = await self.client.auth.onAuthStateChange { [weak self] event, session in
                Task { @MainActor in
                    self?.isAuthenticated = (session != nil)
                }
            }
        }
    }

    private func loadInitialSession() async {
        // Determine auth state via currentUser; avoid try/catch and nil-compare on non-optional types
        if client.auth.currentUser != nil {
            isAuthenticated = true
        } else {
            isAuthenticated = false
        }
    }
}

