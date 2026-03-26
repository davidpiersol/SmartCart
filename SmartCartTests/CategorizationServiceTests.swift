import XCTest
@testable import SmartCart

final class CategorizationServiceTests: XCTestCase {
    private let sut = RuleBasedCategorizationService()

    func testIceCreamIsFrozenNotDairy() {
        XCTAssertEqual(sut.suggestedCategory(for: "Ice cream").rawValue, GroceryCategory.frozen.rawValue)
        XCTAssertEqual(sut.suggestedCategory(for: "Ben & Jerry's ice cream").rawValue, GroceryCategory.frozen.rawValue)
        XCTAssertEqual(sut.suggestedCategory(for: "gelato").rawValue, GroceryCategory.frozen.rawValue)
    }

    func testSourCreamStaysDairy() {
        XCTAssertEqual(sut.suggestedCategory(for: "sour cream").rawValue, GroceryCategory.dairy.rawValue)
        XCTAssertEqual(sut.suggestedCategory(for: "heavy cream").rawValue, GroceryCategory.dairy.rawValue)
    }

    func testCherriesAndBerriesAreProduce() {
        XCTAssertEqual(sut.suggestedCategory(for: "cherries").rawValue, GroceryCategory.produce.rawValue)
        XCTAssertEqual(sut.suggestedCategory(for: "sweet cherries").rawValue, GroceryCategory.produce.rawValue)
        XCTAssertEqual(sut.suggestedCategory(for: "strawberries").rawValue, GroceryCategory.produce.rawValue)
    }

    func testDairyKeywords() {
        XCTAssertEqual(sut.suggestedCategory(for: "Whole milk").rawValue, GroceryCategory.dairy.rawValue)
        XCTAssertEqual(sut.suggestedCategory(for: "cheddar cheese").rawValue, GroceryCategory.dairy.rawValue)
        XCTAssertEqual(sut.suggestedCategory(for: "Greek yogurt").rawValue, GroceryCategory.dairy.rawValue)
    }

    func testProduceKeywords() {
        XCTAssertEqual(sut.suggestedCategory(for: "Bananas").rawValue, GroceryCategory.produce.rawValue)
        XCTAssertEqual(sut.suggestedCategory(for: "baby spinach").rawValue, GroceryCategory.produce.rawValue)
    }

    func testMeatKeywords() {
        XCTAssertEqual(sut.suggestedCategory(for: "Chicken breast").rawValue, GroceryCategory.meat.rawValue)
        XCTAssertEqual(sut.suggestedCategory(for: "ground beef").rawValue, GroceryCategory.meat.rawValue)
    }

    func testHouseholdKeywords() {
        XCTAssertEqual(sut.suggestedCategory(for: "dish soap").rawValue, GroceryCategory.household.rawValue)
    }

    func testUnknownFallsBackToOther() {
        XCTAssertEqual(sut.suggestedCategory(for: "asdfghjkl").rawValue, GroceryCategory.other.rawValue)
    }

    func testWhitespaceTrimmed() {
        XCTAssertEqual(sut.suggestedCategory(for: "   milk   ").rawValue, GroceryCategory.dairy.rawValue)
    }

    func testEmptyNameIsOther() {
        XCTAssertEqual(sut.suggestedCategory(for: "").rawValue, GroceryCategory.other.rawValue)
    }
}
