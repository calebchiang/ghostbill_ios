//
//  RootView.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-10.
//

import SwiftUI
import Supabase

struct Profile: Decodable {
    let id: UUID
    let user_id: UUID
    let currency: String?
    let onboarding_complete: Bool
}

struct RootView: View {
    @EnvironmentObject var session: SessionStore
    @State private var profile: Profile?
    @State private var loading = true

    var body: some View {
        Group {
            if !session.isAuthenticated {
                ContentView()
            } else if loading {
                ProgressView("Loading...")
            } else if let profile = profile, !profile.onboarding_complete {
                OnboardingView {
                    Task { await loadProfile() }
                }
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(.dark) 
        .task(id: session.isAuthenticated) {
            if session.isAuthenticated {
                loading = true
                await loadProfile()
            } else {
                profile = nil
                loading = false
            }
        }
    }

    private func loadProfile() async {
        guard let user = try? await SupabaseManager.shared.client.auth.session.user else {
            loading = false
            return
        }

        do {
            let fetched: Profile = try await SupabaseManager.shared.client
                .from("profiles")
                .select()
                .eq("user_id", value: user.id)
                .single()
                .execute()
                .value

            self.profile = fetched
        } catch {
            self.profile = nil
        }

        self.loading = false
    }
}

