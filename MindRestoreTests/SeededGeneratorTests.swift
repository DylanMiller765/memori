import XCTest
@testable import MindRestore

final class SeededGeneratorTests: XCTestCase {

    // MARK: - Determinism

    func testSameSeedProducesSameSequence() {
        var rng1 = SeededGenerator(seed: 42)
        var rng2 = SeededGenerator(seed: 42)

        for _ in 0..<100 {
            XCTAssertEqual(rng1.next(), rng2.next())
        }
    }

    func testDifferentSeedsProduceDifferentSequences() {
        var rng1 = SeededGenerator(seed: 42)
        var rng2 = SeededGenerator(seed: 43)

        // At least one value should differ in 10 iterations
        var allSame = true
        for _ in 0..<10 {
            if rng1.next() != rng2.next() {
                allSame = false
                break
            }
        }
        XCTAssertFalse(allSame, "Different seeds should produce different sequences")
    }

    // MARK: - Swift Random API Compatibility

    func testWorksWithIntRandom() {
        var rng1 = SeededGenerator(seed: 100)
        var rng2 = SeededGenerator(seed: 100)

        let val1 = Int.random(in: 0..<1000, using: &rng1)
        let val2 = Int.random(in: 0..<1000, using: &rng2)

        XCTAssertEqual(val1, val2)
    }

    func testWorksWithArrayShuffle() {
        var rng1 = SeededGenerator(seed: 200)
        var rng2 = SeededGenerator(seed: 200)

        let arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let shuffled1 = arr.shuffled(using: &rng1)
        let shuffled2 = arr.shuffled(using: &rng2)

        XCTAssertEqual(shuffled1, shuffled2)
    }

    func testWorksWithRandomElement() {
        var rng1 = SeededGenerator(seed: 300)
        var rng2 = SeededGenerator(seed: 300)

        let arr = ["apple", "banana", "cherry", "date", "elderberry"]

        for _ in 0..<20 {
            let pick1 = arr.randomElement(using: &rng1)
            let pick2 = arr.randomElement(using: &rng2)
            XCTAssertEqual(pick1, pick2)
        }
    }

    func testWorksWithBoolRandom() {
        var rng1 = SeededGenerator(seed: 400)
        var rng2 = SeededGenerator(seed: 400)

        for _ in 0..<50 {
            XCTAssertEqual(Bool.random(using: &rng1), Bool.random(using: &rng2))
        }
    }

    // MARK: - Distribution (sanity check)

    func testProducesVariedOutput() {
        var rng = SeededGenerator(seed: 500)
        var values = Set<UInt64>()

        for _ in 0..<100 {
            values.insert(rng.next())
        }

        // 100 random values should be mostly unique
        XCTAssertGreaterThan(values.count, 90, "Should produce varied output")
    }
}
