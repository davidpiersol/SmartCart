import SwiftUI

/// Stable grocery taxonomy persisted as `rawValue` in Core Data (`ShoppingItem.category`).
/// Extend with new cases here; unknown legacy strings resolve to `.other` at read time.
enum GroceryCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case produce = "Produce"
    case dairy = "Dairy"
    case meat = "Meat"
    case bakery = "Bakery"
    case frozen = "Frozen"
    case pantry = "Pantry"
    case beverages = "Beverages"
    case household = "Household"
    case other = "Other"

    var id: String { rawValue }

    /// Fixed aisle-style ordering for grouped UI (not alphabetical).
    static let displayOrder: [GroceryCategory] = [
        .produce, .dairy, .meat, .bakery, .frozen, .pantry, .beverages, .household, .other,
    ]

    /// Resolve persisted string; invalid or empty values become `.other`.
    static func resolved(from raw: String?) -> GroceryCategory {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return .other
        }
        return GroceryCategory(rawValue: raw) ?? .other
    }

    var displayName: String { rawValue }

    var symbolName: String {
        switch self {
        case .produce: return "leaf.fill"
        case .dairy: return "drop.fill"
        case .meat: return "fish.fill"
        case .bakery: return "birthday.cake.fill"
        case .frozen: return "snowflake"
        case .pantry: return "cabinet.fill"
        case .beverages: return "cup.and.saucer.fill"
        case .household: return "house.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }

    var tint: Color {
        switch self {
        case .produce: return .green
        case .dairy: return .cyan
        case .meat: return .red
        case .bakery: return .orange
        case .frozen: return .blue
        case .pantry: return .brown
        case .beverages: return .purple
        case .household: return .indigo
        case .other: return .secondary
        }
    }
}

/// How the user chose a category when adding an item (ViewModel maps to persistence flags).
enum CategorySelectionMode: Equatable, Hashable, Sendable {
    /// Rule-based (or future ML) suggestion; `categoryManualOverride` stays false.
    case automatic
    /// User explicitly picked a category; never auto-overwritten later.
    case manual(GroceryCategory)
}
