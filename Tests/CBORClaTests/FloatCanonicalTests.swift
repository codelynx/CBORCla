import XCTest
@testable import CBORCla

final class FloatCanonicalTests: XCTestCase {
    var encoder: CBOREncoder!
    var decoder: CBORDecoder!

    override func setUp() {
        super.setUp()
        encoder = CBOREncoder()
        encoder.options.useCanonicalEncoding = true
        decoder = CBORDecoder()
    }

    // MARK: - NaN Tests

    func testCanonicalNaN() throws {
        // NaN should always encode to 0xf97e00 in canonical form
        let nanFloat = Float.nan
        let nanDouble = Double.nan

        let floatData = try encoder.encode(nanFloat)
        let doubleData = try encoder.encode(nanDouble)

        // Both should encode to the same canonical NaN representation
        XCTAssertEqual(floatData, Data([0xf9, 0x7e, 0x00]))
        XCTAssertEqual(doubleData, Data([0xf9, 0x7e, 0x00]))

        // Verify they decode correctly
        let decodedFloat = try decoder.decode(Float.self, from: floatData)
        let decodedDouble = try decoder.decode(Double.self, from: doubleData)

        XCTAssertTrue(decodedFloat.isNaN)
        XCTAssertTrue(decodedDouble.isNaN)
    }

    // MARK: - Infinity Tests

    func testCanonicalInfinity() throws {
        // Positive infinity
        let posInfFloat = Float.infinity
        let posInfDouble = Double.infinity

        let posFloatData = try encoder.encode(posInfFloat)
        let posDoubleData = try encoder.encode(posInfDouble)

        // Both should encode to Float16 +Infinity
        XCTAssertEqual(posFloatData, Data([0xf9, 0x7c, 0x00]))
        XCTAssertEqual(posDoubleData, Data([0xf9, 0x7c, 0x00]))

        // Negative infinity
        let negInfFloat = -Float.infinity
        let negInfDouble = -Double.infinity

        let negFloatData = try encoder.encode(negInfFloat)
        let negDoubleData = try encoder.encode(negInfDouble)

        // Both should encode to Float16 -Infinity
        XCTAssertEqual(negFloatData, Data([0xf9, 0xfc, 0x00]))
        XCTAssertEqual(negDoubleData, Data([0xf9, 0xfc, 0x00]))
    }

    // MARK: - Zero Tests

    func testCanonicalZero() throws {
        // Positive zero
        let posZeroFloat: Float = 0.0
        let posZeroDouble: Double = 0.0

        let posFloatData = try encoder.encode(posZeroFloat)
        let posDoubleData = try encoder.encode(posZeroDouble)

        // Both should encode to Float16 +0.0
        XCTAssertEqual(posFloatData, Data([0xf9, 0x00, 0x00]))
        XCTAssertEqual(posDoubleData, Data([0xf9, 0x00, 0x00]))

        // Negative zero
        let negZeroFloat: Float = -0.0
        let negZeroDouble: Double = -0.0

        let negFloatData = try encoder.encode(negZeroFloat)
        let negDoubleData = try encoder.encode(negZeroDouble)

        // Both should encode to Float16 -0.0
        XCTAssertEqual(negFloatData, Data([0xf9, 0x80, 0x00]))
        XCTAssertEqual(negDoubleData, Data([0xf9, 0x80, 0x00]))

        // Verify they decode correctly and preserve sign
        let decodedPosFloat = try decoder.decode(Float.self, from: posFloatData)
        let decodedNegFloat = try decoder.decode(Float.self, from: negFloatData)

        XCTAssertEqual(decodedPosFloat, 0.0)
        XCTAssertEqual(decodedNegFloat, -0.0)
        XCTAssertEqual(decodedPosFloat.sign, .plus)
        XCTAssertEqual(decodedNegFloat.sign, .minus)
    }

    // MARK: - Subnormal Tests

    func testSubnormalNumbers() throws {
        // When encoding a Float that would be subnormal in Float16, use Float32
        let tinyFloat: Float = 1e-7  // Too small for Float16
        let tinyData = try encoder.encode(tinyFloat)

        // Should be encoded as Float32 (0xfa prefix) in canonical mode
        XCTAssertEqual(tinyData[0], 0xfa)

        // Test Float16 smallest normal value
        let smallestNormal: Float = Float(Float16.leastNormalMagnitude)
        let smallestNormalData = try encoder.encode(smallestNormal)

        // Should be encoded as Float16 (0xf9 prefix)
        XCTAssertEqual(smallestNormalData[0], 0xf9)
    }

    // MARK: - Shortest Form Tests

    func testShortestFormEncoding() throws {
        // Test values that can be exactly represented in Float16
        let half: Float = 0.5
        let one: Float = 1.0
        let two: Float = 2.0

        let halfData = try encoder.encode(half)
        let oneData = try encoder.encode(one)
        let twoData = try encoder.encode(two)

        // All should be encoded as Float16 (3 bytes with 0xf9 prefix)
        XCTAssertEqual(halfData.count, 3)
        XCTAssertEqual(halfData[0], 0xf9)

        XCTAssertEqual(oneData.count, 3)
        XCTAssertEqual(oneData[0], 0xf9)

        XCTAssertEqual(twoData.count, 3)
        XCTAssertEqual(twoData[0], 0xf9)

        // Test value that requires Float32
        let pi: Float = 3.14159265
        let piData = try encoder.encode(pi)

        // Should be encoded as Float32 (5 bytes with 0xfa prefix)
        XCTAssertEqual(piData.count, 5)
        XCTAssertEqual(piData[0], 0xfa)

        // Test value that requires Float64
        let bigDouble: Double = 1.234567890123456789
        let bigData = try encoder.encode(bigDouble)

        // Should be encoded as Float64 (9 bytes with 0xfb prefix)
        XCTAssertEqual(bigData.count, 9)
        XCTAssertEqual(bigData[0], 0xfb)
    }

    // MARK: - Round-trip Tests

    func testCanonicalFloatRoundTrip() throws {
        let values: [Float] = [
            0.0, -0.0, 1.0, -1.0, 0.5, -0.5,
            Float.pi, Float.infinity, -Float.infinity, Float.nan,
            1e-5, 1e5, Float.leastNormalMagnitude, Float.greatestFiniteMagnitude
        ]

        for value in values {
            let encoded = try encoder.encode(value)
            let decoded = try decoder.decode(Float.self, from: encoded)

            if value.isNaN {
                XCTAssertTrue(decoded.isNaN, "NaN not preserved")
            } else {
                XCTAssertEqual(decoded, value, "Value \(value) not preserved")
            }

            // Check sign preservation for zero
            if value == 0.0 {
                XCTAssertEqual(decoded.sign, value.sign, "Zero sign not preserved")
            }
        }
    }

    func testCanonicalDoubleRoundTrip() throws {
        let values: [Double] = [
            0.0, -0.0, 1.0, -1.0, 0.5, -0.5,
            Double.pi, Double.infinity, -Double.infinity, Double.nan,
            1e-10, 1e10, Double.leastNormalMagnitude, Double.greatestFiniteMagnitude
        ]

        for value in values {
            let encoded = try encoder.encode(value)
            let decoded = try decoder.decode(Double.self, from: encoded)

            if value.isNaN {
                XCTAssertTrue(decoded.isNaN, "NaN not preserved")
            } else {
                XCTAssertEqual(decoded, value, "Value \(value) not preserved")
            }

            // Check sign preservation for zero
            if value == 0.0 {
                XCTAssertEqual(decoded.sign, value.sign, "Zero sign not preserved")
            }
        }
    }

    // MARK: - Non-Canonical Mode Tests

    func testNonCanonicalMode() throws {
        encoder.options.useCanonicalEncoding = false

        // In non-canonical mode, Float should always use Float32
        let value: Float = 1.0
        let data = try encoder.encode(value)

        // Should be Float32 (5 bytes)
        XCTAssertEqual(data.count, 5)
        XCTAssertEqual(data[0], 0xfa)

        // Double should always use Float64
        let doubleValue: Double = 1.0
        let doubleData = try encoder.encode(doubleValue)

        // Should be Float64 (9 bytes)
        XCTAssertEqual(doubleData.count, 9)
        XCTAssertEqual(doubleData[0], 0xfb)
    }
}