// SuperbrainTests/PredicateBuilderTests.swift
import XCTest
@testable import Superbrain

final class PredicateBuilderTests: XCTestCase {
    func test_emptyBuilder_returnsNil() {
        XCTAssertNil(PredicateBuilder().build())
    }

    func test_whitespaceText_returnsNil() {
        XCTAssertNil(PredicateBuilder().withText("   ").build())
    }

    func test_textFilter_containsKeyword() {
        let predicate = PredicateBuilder().withText("hello").build()
        XCTAssertNotNil(predicate)
        // 验证是比较谓词（而非依赖不稳定的 predicateFormat 字符串）
        XCTAssertTrue(predicate is NSComparisonPredicate, "单文本条件应返回 NSComparisonPredicate")
    }

    func test_dateRange_generatesPredicate() {
        let start = Date(timeIntervalSinceNow: -86400)
        let end = Date()
        let predicate = PredicateBuilder().withDateRange(start: start, end: end).build()
        XCTAssertNotNil(predicate)
    }

    func test_emptyTagSet_returnsNil() {
        XCTAssertNil(PredicateBuilder().withTags([]).build())
    }

    func test_tagFilter_generatesPredicate() {
        let predicate = PredicateBuilder().withTags(["工作"]).build()
        XCTAssertNotNil(predicate)
    }

    func test_multipleConditions_usesAND() {
        let predicate = PredicateBuilder()
            .withText("test")
            .withTags(["工作"])
            .build()
        let compound = predicate as? NSCompoundPredicate
        XCTAssertNotNil(compound, "多条件应返回 NSCompoundPredicate")
        XCTAssertEqual(compound?.compoundPredicateType, .and)
        XCTAssertEqual(compound?.subpredicates.count, 2)
    }
}
