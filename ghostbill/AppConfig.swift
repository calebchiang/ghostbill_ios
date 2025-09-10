//
//  AppConfig.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-09.
//

import Foundation

enum AppConfig {
    private static let dict: [String: Any] = {
        guard
            let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dict = obj as? [String: Any]
        else {
            assertionFailure("Config.plist missing or unreadable")
            return [:]
        }
        return dict
    }()

    static var supabaseURL: String { dict["SUPABASE_URL"] as? String ?? "" }
    static var supabaseAnonKey: String { dict["SUPABASE_ANON_KEY"] as? String ?? "" }
    static var redirectURLString: String { dict["REDIRECT_URL"] as? String ?? "" }
}

