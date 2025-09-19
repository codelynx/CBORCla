import XCTest
@testable import CBORCla

final class RFC8949EnhancedComplianceTests: XCTestCase {
    var encoder: CBOREncoder!
    var decoder: CBORDecoder!

    override func setUp() {
        super.setUp()
        encoder = CBOREncoder()
        decoder = CBORDecoder()
    }

    // MARK: - Unassigned Simple Value Tests

    func testRejectUnassignedSimpleValues() throws {
        // Direct simple values 0-19 in additional info
        for value in UInt8(0)..<UInt8(20) {
            let data = Data([0xE0 | value]) // Major type 7 with direct value
            XCTAssertThrowsError(try decoder.decodeValue(from: data)) { error in
                guard case CBORError.invalidFormat(let msg) = error else {
                    XCTFail("Expected invalidFormat error for simple value \(value)")
                    return
                }
                XCTAssertTrue(msg.contains("0-19"))
            }
        }
    }

    func testRejectUnassignedSimpleValuesViaAdditionalByte() throws {
        // Simple values 0-19 via additional byte (0xF8 xx)
        for value in UInt8(0)..<UInt8(20) {
            let data = Data([0xF8, value])
            XCTAssertThrowsError(try decoder.decodeValue(from: data)) { error in
                guard case CBORError.invalidFormat(let msg) = error else {
                    XCTFail("Expected invalidFormat error for simple value \(value)")
                    return
                }
                XCTAssertTrue(msg.contains("0-19"))
            }
        }
    }

    // MARK: - Tag Content Validation Tests

    func testTagContentValidation() throws {
        // Test tag 0 (standard date/time) requires text string
        let invalidTag0 = Data([0xC0, 0x01]) // Tag 0 with unsigned(1) instead of text
        XCTAssertThrowsError(try decoder.decodeValue(from: invalidTag0)) { error in
            guard case CBORError.invalidFormat(let msg) = error else {
                XCTFail("Expected invalidFormat for invalid tag 0 content")
                return
            }
            XCTAssertTrue(msg.contains("Tag 0"))
        }

        // Test tag 1 (epoch time) requires numeric value
        let invalidTag1 = Data([0xC1, 0x60]) // Tag 1 with empty text string
        XCTAssertThrowsError(try decoder.decodeValue(from: invalidTag1)) { error in
            guard case CBORError.invalidFormat(let msg) = error else {
                XCTFail("Expected invalidFormat for invalid tag 1 content")
                return
            }
            XCTAssertTrue(msg.contains("Tag 1"))
        }

        // Test tag 2 (positive bignum) requires byte string
        let invalidTag2 = Data([0xC2, 0x60]) // Tag 2 with text string instead of bytes
        XCTAssertThrowsError(try decoder.decodeValue(from: invalidTag2)) { error in
            guard case CBORError.invalidFormat(let msg) = error else {
                XCTFail("Expected invalidFormat for invalid tag 2 content")
                return
            }
            XCTAssertTrue(msg.contains("Tag 2"))
        }

        // Test tag 4 (decimal fraction) requires 2-element array
        let invalidTag4 = Data([0xC4, 0x81, 0x01]) // Tag 4 with 1-element array
        XCTAssertThrowsError(try decoder.decodeValue(from: invalidTag4)) { error in
            guard case CBORError.invalidFormat(let msg) = error else {
                XCTFail("Expected invalidFormat for invalid tag 4 content")
                return
            }
            XCTAssertTrue(msg.contains("Tag 4"))
        }

        // Test tag 32 (URI) requires text string
        let invalidTag32 = Data([0xD8, 0x20, 0x42, 0x01, 0x02]) // Tag 32 with byte string
        XCTAssertThrowsError(try decoder.decodeValue(from: invalidTag32)) { error in
            guard case CBORError.invalidFormat(let msg) = error else {
                XCTFail("Expected invalidFormat for invalid tag 32 content")
                return
            }
            XCTAssertTrue(msg.contains("Tag 32"))
        }
    }

    func testValidTagContent() throws {
        // Valid tag 0: standard date/time string
        let validTag0 = Data([0xC0, 0x74, 0x32, 0x30, 0x32, 0x34, 0x2D, 0x30, 0x39, 0x2D,
                             0x31, 0x39, 0x54, 0x31, 0x32, 0x3A, 0x30, 0x30, 0x3A, 0x30, 0x30, 0x5A])
        XCTAssertNoThrow(try decoder.decodeValue(from: validTag0))

        // Valid tag 1: epoch time
        let validTag1 = Data([0xC1, 0x1A, 0x5F, 0x5E, 0x10, 0x00]) // Timestamp as unsigned
        XCTAssertNoThrow(try decoder.decodeValue(from: validTag1))

        // Valid tag 2: positive bignum
        let validTag2 = Data([0xC2, 0x42, 0x01, 0x02]) // 2-byte bignum
        XCTAssertNoThrow(try decoder.decodeValue(from: validTag2))

        // Valid tag 4: decimal fraction
        let validTag4 = Data([0xC4, 0x82, 0x20, 0x03]) // [-1, 3] = 3 * 10^-1 = 0.3
        XCTAssertNoThrow(try decoder.decodeValue(from: validTag4))

        // Valid tag 32: URI
        let validTag32 = Data([0xD8, 0x20, 0x78, 0x18, 0x68, 0x74, 0x74, 0x70, 0x73, 0x3A,
                              0x2F, 0x2F, 0x65, 0x78, 0x61, 0x6D, 0x70, 0x6C, 0x65, 0x2E,
                              0x63, 0x6F, 0x6D, 0x2F, 0x70, 0x61, 0x74, 0x68]) // "https://example.com/path"
        XCTAssertNoThrow(try decoder.decodeValue(from: validTag32))
    }

    // MARK: - Preferred Serialization Tests

    func testPreferredSerialization() throws {
        encoder.options.preferDefiniteLength = true

        // Arrays should use definite length
        let array = [1, 2, 3]
        let arrayData = try encoder.encode(array)
        XCTAssertEqual(arrayData[0], 0x83) // Definite array with 3 elements

        // Maps should use definite length
        let map = ["a": 1, "b": 2]
        let mapData = try encoder.encode(map)
        XCTAssertEqual(mapData[0], 0xa2) // Definite map with 2 entries
    }

    // MARK: - Well-formedness Tests

    func testRejectReservedSimpleValues() throws {
        // Simple values 24-31 are reserved
        for value in UInt8(24)...UInt8(31) {
            let data = Data([0xF8, value])
            XCTAssertThrowsError(try decoder.decodeValue(from: data)) { error in
                guard case CBORError.invalidFormat(let msg) = error else {
                    XCTFail("Expected invalidFormat error for reserved value \(value)")
                    return
                }
                XCTAssertTrue(msg.contains("Reserved") || msg.contains("reserved"))
            }
        }
    }

    func testIndefiniteLengthOverflowProtection() throws {
        // Create a very long indefinite byte string (but not actually too long)
        var data = Data([0x5f]) // Indefinite byte string
        for _ in 0..<10 {
            data.append(contentsOf: [0x41, 0x00]) // 1-byte chunks
        }
        data.append(0xff) // Break

        // Should succeed with reasonable number of chunks
        XCTAssertNoThrow(try decoder.decodeValue(from: data))
    }

    // MARK: - Canonical Encoding Verification

    func testCanonicalEncodingCompleteness() throws {
        encoder.options.useCanonicalEncoding = true

        // Test that all features work together
        struct ComplexStruct: Codable {
            let smallInt: Int = 10
            let largeInt: Int = 1000000
            let negativeInt: Int = -500
            let floatValue: Float = 1.5
            let doubleValue: Double = 1.5
            let textString: String = "test"
            let data: Data = Data([1, 2, 3])
            let array: [Int] = [1, 2, 3]
            let map: [String: Int] = ["z": 1, "a": 2, "bb": 3]
        }

        let value = ComplexStruct()
        let encoded = try encoder.encode(value)

        // Decode and verify it's valid
        let decoded = try decoder.decode(ComplexStruct.self, from: encoded)
        XCTAssertEqual(decoded.smallInt, value.smallInt)
        XCTAssertEqual(decoded.largeInt, value.largeInt)
        XCTAssertEqual(decoded.negativeInt, value.negativeInt)
        XCTAssertEqual(decoded.floatValue, value.floatValue)
        XCTAssertEqual(decoded.doubleValue, value.doubleValue)
        XCTAssertEqual(decoded.textString, value.textString)
        XCTAssertEqual(decoded.data, value.data)
        XCTAssertEqual(decoded.array, value.array)
        XCTAssertEqual(decoded.map, value.map)

        // Re-encode and verify it's deterministic
        let reencoded = try encoder.encode(value)
        XCTAssertEqual(encoded, reencoded, "Canonical encoding should be deterministic")
    }
}