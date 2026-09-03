import XCTest
@testable import FarkleCore

final class ScoringTests: XCTestCase {
    func testSingles() {
        XCTAssertEqual(Scoring.score(faces: [1]), 100)
        XCTAssertEqual(Scoring.score(faces: [5]), 50)
        XCTAssertEqual(Scoring.score(faces: [1, 5]), 150)
        XCTAssertNil(Scoring.score(faces: [2]))
        XCTAssertNil(Scoring.score(faces: [2, 2]))
        XCTAssertNil(Scoring.score(faces: [1, 2]))
    }

    func testTriplesAndBeyond() {
        XCTAssertEqual(Scoring.score(faces: [1, 1, 1]), 1000)
        XCTAssertEqual(Scoring.score(faces: [2, 2, 2]), 200)
        XCTAssertEqual(Scoring.score(faces: [6, 6, 6]), 600)
        XCTAssertEqual(Scoring.score(faces: [1, 1, 1, 1]), 2000)
        XCTAssertEqual(Scoring.score(faces: [1, 1, 1, 1, 1]), 4000)
        XCTAssertEqual(Scoring.score(faces: [1, 1, 1, 1, 1, 1]), 8000)
        XCTAssertEqual(Scoring.score(faces: [4, 4, 4, 4]), 800)
        XCTAssertEqual(Scoring.score(faces: [5, 5, 5, 5, 5, 5]), 4000)
        XCTAssertEqual(Scoring.score(faces: [2, 2, 2, 3, 3, 3]), 500)
    }

    func testMixed() {
        XCTAssertEqual(Scoring.score(faces: [1, 4, 4, 4, 5]), 550)
        XCTAssertEqual(Scoring.score(faces: [5, 5, 5, 1]), 600)
        XCTAssertNil(Scoring.score(faces: [4, 4, 4, 6]))
    }

    func testStraights() {
        XCTAssertEqual(Scoring.score(faces: [1, 2, 3, 4, 5]), 500)
        XCTAssertEqual(Scoring.score(faces: [2, 3, 4, 5, 6]), 750)
        XCTAssertEqual(Scoring.score(faces: [1, 2, 3, 4, 5, 6]), 1500)
        XCTAssertEqual(Scoring.score(faces: [1, 2, 3, 4, 5, 5]), 550)
        XCTAssertEqual(Scoring.score(faces: [1, 1, 2, 3, 4, 5]), 600)
        XCTAssertNil(Scoring.score(faces: [2, 3, 4, 5, 6, 6]))
    }

    func testDescribe() {
        XCTAssertEqual(Scoring.describe(Scoring.faceCounts([1, 4, 4, 4, 5])), "three 4s + 1 + 5")
        XCTAssertEqual(Scoring.describe(Scoring.faceCounts([1, 2, 3, 4, 5])), "straight 1-5")
        XCTAssertEqual(Scoring.describe(Scoring.faceCounts([1, 1, 1, 1])), "four 1s")
    }

    func testCatalogMatchesPublishedOdds() {
        let weighted = DieType.named("Weighted die")!
        XCTAssertEqual(weighted.probability(ofFace: 1), 10.0 / 15.0, accuracy: 1e-9)
        let pie = DieType.named("Pie die")!
        XCTAssertEqual(pie.probability(ofFace: 5), 0)
        XCTAssertEqual(DieType.catalog.count, 40)
        XCTAssertTrue(DieType.named("Hugo's Die")!.isUniform)
    }
}
