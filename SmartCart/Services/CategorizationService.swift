import Foundation

/// Pluggable categorization seam: swap in Core ML, remote API, or Apple Intelligence later.
protocol ItemCategorizing: Sendable {
    /// Returns a category for a free-text item name (trimmed by callers as needed).
    func suggestedCategory(for itemName: String) -> GroceryCategory
}

/// Rule-based grocery mapping tuned for **aisle-like** behavior without a model.
///
/// **Why not only substring keywords?** A bare keyword like `"cream"` matches `"ice cream"` as Dairy
/// before Frozen is ever considered. This service therefore:
/// 1. Applies **priority phrases** (longest first) so multi-word foods resolve correctly.
/// 2. Evaluates categories in **`ruleEvaluationOrder`** (Frozen before Dairy) for remaining substring rules.
/// 3. Optionally matches **whole words** for short keywords to reduce junk hits.
///
/// **Going beyond rules:** Replace this type with an implementation that calls
/// `NaturalLanguage` tagging, a small Core ML classifier, or an API—`SmartCartViewModel`
/// already injects `ItemCategorizing`.
struct RuleBasedCategorizationService: ItemCategorizing {

    func suggestedCategory(for itemName: String) -> GroceryCategory {
        let normalized = Self.normalize(itemName)
        guard !normalized.isEmpty else { return .other }

        // 1) Longest multi-word / high-signal phrases first (prevents "cream" stealing "ice cream").
        for (phrase, category) in Self.priorityPhrasesLongestFirst {
            if normalized.range(of: phrase, options: .literal) != nil {
                return category
            }
        }

        // 2) Category rules in aisle-aware order (Frozen before Dairy, etc.).
        for category in Self.ruleEvaluationOrder where category != .other {
            guard let keywords = Self.keywordRules[category] else { continue }
            if keywords.contains(where: { keyword in
                Self.matchesKeyword(normalized, keyword: keyword)
            }) {
                return category
            }
        }

        // 3) Whole-word pass for produce fruit names that substring rules might miss.
        if let produce = Self.produceWordHintsMatch(normalized) {
            return produce
        }

        return .other
    }

    // MARK: - Matching

    /// Substring match, but short keywords (≤3 chars) require a word boundary to avoid noise.
    private static func matchesKeyword(_ normalized: String, keyword: String) -> Bool {
        guard !keyword.isEmpty else { return false }
        if keyword.count <= 3 {
            return wholeWordMatch(normalized, word: keyword)
        }
        return normalized.range(of: keyword, options: .literal) != nil
    }

    private static func wholeWordMatch(_ normalized: String, word: String) -> Bool {
        let parts = normalized.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        return parts.contains { String($0) == word }
    }

    private static func normalize(_ name: String) -> String {
        name
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Frozen & other departments before Dairy so `"cream"` in dairy does not capture `"ice cream"`.
    private static let ruleEvaluationOrder: [GroceryCategory] = [
        .produce, .frozen, .dairy, .meat, .bakery, .pantry, .beverages, .household,
    ]

    /// Longest phrases first — built once so `"ice cream"` beats `"ice"` if both existed.
    private static let priorityPhrasesLongestFirst: [(phrase: String, category: GroceryCategory)] = {
        let raw: [(String, GroceryCategory)] = [
            // Frozen desserts & meals (before any generic "cream" / dairy)
            ("frozen whipped topping", .frozen),
            ("ice cream", .frozen),
            ("icecream", .frozen),
            ("frozen yogurt", .frozen),
            ("frozen yoghurt", .frozen),
            ("frozen pizza", .frozen),
            ("frozen meal", .frozen),
            ("frozen vegetables", .frozen),
            ("frozen veg", .frozen),
            ("frozen fruit", .frozen),
            ("frozen berries", .frozen),
            ("tv dinner", .frozen),
            ("frozen dinner", .frozen),
            ("gelato", .frozen),
            ("sorbet", .frozen),
            ("popsicle", .frozen),
            ("ice pop", .frozen),
            ("ice lolly", .frozen),
            ("frozen waffle", .frozen),
            ("frozen fries", .frozen),
            ("frozen chips", .frozen),
            ("perogies", .frozen),
            ("perogy", .frozen),
            ("frozen burrito", .frozen),
            // Dairy phrases that contain "cream"
            ("sour cream", .dairy),
            ("heavy cream", .dairy),
            ("whipping cream", .dairy),
            ("double cream", .dairy),
            ("clotted cream", .dairy),
            ("cream cheese", .dairy),
            ("creamer", .dairy),
            ("coffee creamer", .dairy),
            ("half and half", .dairy),
            ("buttermilk", .dairy),
        ]
        return raw.sorted { $0.0.count > $1.0.count }
    }()

    /// Extra produce hits: whole-word only (cherries, strawberries, …).
    private static func produceWordHintsMatch(_ normalized: String) -> GroceryCategory? {
        let hints: [String] = [
            "cherries", "cherry", "strawberries", "strawberry", "raspberries", "raspberry",
            "blueberries", "blueberry", "blackberries", "blackberry", "cranberries", "cranberry",
            "currants", "currant", "gooseberries", "gooseberry", "kiwi", "kiwis",
            "apricots", "apricot", "nectarines", "nectarine", "plums", "plum", "figs", "fig",
            "dates", "date", "pomegranate", "pomegranates", "clementines", "clementine",
            "tangerines", "tangerine", "mandarins", "mandarin", "grapefruit", "grapefruits",
            "cantaloupe", "honeydew", "papaya", "papayas", "dragonfruit", "passion fruit",
            "plantains", "plantain", "rhubarb", "kale", "chard", "arugula", "rocket",
            "bok choy", "scallions", "shallots", "leeks", "radishes", "radish", "turnips", "beets",
            "jicama", "edamame", "snap peas", "snow peas", "green beans", "brussels sprouts",
        ]
        for h in hints {
            if h.contains(" ") {
                if normalized.range(of: h, options: .literal) != nil { return .produce }
            } else if wholeWordMatch(normalized, word: h) {
                return .produce
            }
        }
        return nil
    }

    /// Per-category substring / word rules. Avoid bare `"cream"` — use phrases in `priorityPhrasesLongestFirst`.
    private static let keywordRules: [GroceryCategory: [String]] = [
        .produce: [
            "apple", "banana", "bananas", "orange", "oranges", "berry", "berries", "grape", "grapes",
            "lettuce", "spinach", "kale", "carrot", "carrots", "onion", "onions", "tomato", "tomatoes",
            "potato", "potatoes", "broccoli", "pepper", "peppers", "bell pepper", "cucumber", "cucumbers",
            "avocado", "avocados", "mushroom", "mushrooms", "lime", "limes", "lemon", "lemons",
            "melon", "watermelon", "pineapple", "pineapples", "mango", "mangoes", "pear", "pears",
            "peach", "peaches", "plum", "plums", "cherry", "cherries",
            "salad", "herb", "herbs", "cilantro", "parsley", "basil", "garlic", "ginger",
            "zucchini", "squash", "corn", "celery", "asparagus", "cabbage", "cauliflower",
            "fruit", "vegetable", "vegetables", "greens", "organic greens",
            "apples", "clementine", "mandarin", "grapefruit",
        ],
        .frozen: [
            "frozen", "freezer", "gelato", "sorbet", "popsicle",
            "waffle", "waffles", "fries", "french fries", "hash browns", "tater tots",
            "pizza", "burrito", "burritos", "spring roll", "egg roll", "dumpling", "dumplings",
            "perogy", "perogies", "frozen peas", "frozen corn",
        ],
        .dairy: [
            "milk", "cheese", "yogurt", "yoghurt", "butter", "cottage", "ricotta",
            "mozzarella", "cheddar", "parmesan", "feta", "kefir",
            "egg", "eggs", "half and half",
            // no bare "cream" — handled by priority phrases
        ],
        .meat: [
            "chicken", "beef", "pork", "turkey", "lamb", "steak", "bacon", "sausage", "ham",
            "salmon", "tuna", "fish", "cod", "tilapia", "shrimp", "seafood", "scallop", "scallops",
            "ground beef", "ribs", "wing", "wings", "drumstick", "cutlet", "prosciutto",
            "hot dog", "bratwurst", "chorizo", "pepperoni",
        ],
        .bakery: [
            "bread", "bagel", "bagels", "muffin", "muffins", "croissant", "croissants", "roll", "rolls",
            "bun", "buns", "cake", "donut", "doughnut", "donuts", "pastry", "pastries",
            "tortilla", "tortillas", "pita", "naan", "biscuit", "biscuits", "sourdough", "baguette",
            "cupcake", "brownie", "brownies", "cookie", "cookies", "pie", "pies",
        ],
        .pantry: [
            "rice", "pasta", "noodle", "noodles", "cereal", "oat", "oats", "flour", "sugar", "salt", "spice",
            "spices", "oil", "olive oil", "vinegar", "sauce", "soup", "broth", "stock", "bean", "beans",
            "lentil", "lentils", "can ", " canned", "honey", "jam", "jelly", "peanut butter",
            "cracker", "crackers", "chip", "chips", "snack", "nuts", "almond", "walnut",
            "quinoa", "couscous", "barley",
        ],
        .beverages: [
            "water", "juice", "soda", "pop", "cola", "coffee", "tea", "beer", "wine", "kombucha",
            "energy drink", "sparkling", "smoothie", "lemonade", "iced tea", "sports drink",
            "seltzer", "tonic", "mixer",
        ],
        .household: [
            "soap", "detergent", "paper towel", "tissue", "toilet paper", "trash bag", "trash bags",
            "cleaner", "sponge", "bleach", "battery", "batteries", "light bulb", "foil", "wrap",
            "ziploc", "plastic bag", "garbage", "lysol", "disinfectant",
        ],
    ]
}
