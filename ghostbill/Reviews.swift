//
//  Reviews.swift
//  ghostbill
//
//  Created by Caleb Chiang on 2025-10-02.
//

import SwiftUI

struct StarsRow: View {
    let count: Int = 5
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .imageScale(.medium)
                    .foregroundColor(.orange)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("5 out of 5 stars")
    }
}

struct Review: Identifiable {
    let id = UUID()
    let name: String
    let age: Int
    let text: String
}

let REVIEWS: [Review] = [
    .init(name: "Sarah", age: 28, text: "GhostBill made my spending obvious at a glance. I now save over $500 every month."),
    .init(name: "Marcus", age: 31, text: "I finally understand where my money goes. No more stress looking at my balance."),
    .init(name: "Ava", age: 25, text: "I used to get overdraft fees from forgotten subscriptions. I now set notifications for payments so I'm always prepared. ")
]

struct ReviewCard: View {
    let review: Review
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.secondary)
                Text("\(review.name), \(review.age)")
                    .font(.headline)
                Spacer()
            }
            StarsRow()
            Text("“\(review.text)”")
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
