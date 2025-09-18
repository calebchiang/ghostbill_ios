//
//  CategoryIcons.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-09-13.
//

import SwiftUI

extension ExpenseCategory {
    /// SF Symbol name for this category
    var symbolName: String {
        switch self {
        case .groceries:      return "cart.fill"
        case .coffee:         return "cup.and.saucer.fill"
        case .dining:         return "fork.knife"
        case .transport:      return "car.fill"
        case .fuel:           return "fuelpump.fill"
        case .shopping:       return "bag.fill"
        case .utilities:      return "bolt.fill"
        case .housing:        return "house.fill"
        case .entertainment:  return "play.circle.fill"
        case .travel:         return "airplane"
        case .personal:       return "person.fill"
        case .income:         return "dollarsign.circle.fill"
        case .other:          return "circle.fill"
        }
    }

    /// Tint color for this category (dark-UI friendly)
    var tint: Color {
        switch self {
        case .groceries:      return .green
        case .coffee:         return .brown
        case .dining:         return .orange
        case .transport:      return .blue
        case .fuel:           return .yellow
        case .shopping:       return .indigo
        case .utilities:      return .teal
        case .housing:        return .purple
        case .entertainment:  return .pink
        case .travel:         return .mint
        case .personal:       return .red                    
        case .income:         return .cyan   // keep if you like the contrast; swap to .green if preferred
        case .other:          return .gray
        }
    }

    /// User-facing title
    var title: String { rawValue.capitalized }
}

/// Small reusable badge for list rows etc.
struct CategoryBadge: View {
    let category: ExpenseCategory

    var body: some View {
        ZStack {
            Circle().fill(category.tint.opacity(0.18))
            Image(systemName: category.symbolName)
                .foregroundColor(category.tint)
                .font(.system(size: 16, weight: .semibold))
        }
        .frame(width: 36, height: 36)
    }
}

