import XCTest
@testable import CBORCla

final class StrictModeTests: XCTestCase {
    var encoder: CBOREncoder!
    var decoder: CBORDecoder!

    override func setUp() {
        super.setUp()
        encoder = CBOREncoder()
        decoder = CBORDecoder()
        decoder.options.strictMode = true  // Enable strict RFC 8949 validation
    }

    // MARK: - Non-Canonical Integer Encoding Tests

    func testRejectNonCanonicalUInt8() throws {
        // Value 10 encoded as 2-byte integer (should be 1-byte)
        let data = Data([0x18, 0x0A]) // Major type 0, additional byte with value 10

        XCTAssertThrowsError(try decoder.decodeValue(from: data)) { error in
            guard case CBORError.invalidFormat(let msg) = error else {
                XCTFail("Expected invalidFormat error for non-canonical encoding")
                return
            }
            XCTAssertTrue(msg.contains("Non-canonical") || msg.contains("should use direct"))
        }
    }

    func testRejectNonCanonicalUInt16() throws {
        // Value 255 encoded as 2-byte integer (should be 1-byte with additional byte)
        let data = Data([0x19, 0x00, 0xFF]) // Major type 0, 2-byte encoding of 255

        XCTAssertThrowsError(try decoder.decodeValue(from: data)) { error in
            guard case CBORError.invalidFormat(let msg) = error else {
                XCTFail("Expected invalidFormat error for non-canonical encoding")
                return
            }
            XCTAssertTrue(msg.contains("Non-canonical") || msg.contains("shorter form"))
        }
    }

    func testRejectNonCanonicalUInt32() throws {
        // Value 65535 encoded as 4-byte integer (should be 2-byte)
        let data = Data([0x1A, 0x00, 0x00, 0xFF, 0xFF]) // Major type 0, 4-byte encoding of 65535

        XCTAssertThrowsError(try decoder.decodeValue(from: data)) { error in
            guard case CBORError.invalidFormat(let msg) = error else {
                XCTFail("Expected invalidFormat error for non-canonical encoding")
                return
            }
            XCTAssertTrue(msg.contains("Non-canonical") || msg.contains("shorter form"))
        }
    }

    func testRejectNonCanonicalUInt64() throws {
        // Value 4294967295 encoded as 8-byte integer (should be 4-byte)
        let data = Data([0x1B, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF]) // Major type 0, 8-byte encoding

        XCTAssertThrowsError(try decoder.decodeValue(from: data)) { error in
            guard case CBORError.invalidFormat(let msg) = error else {
                XCTFail("Expected invalidFormat error for non-canonical encoding")
                return
            }
            XCTAssertTrue(msg.contains("Non-canonical") || msg.contains("shorter form"))
        }
    }

    func testAcceptCanonicalEncodings() throws {
        // Test that properly encoded values are accepted in strict mode

        // Direct encoding (0-23)
        let direct = Data([0x0A]) // 10 encoded directly
        XCTAssertNoThrow(try decoder.decodeValue(from: direct))

        // 1-byte encoding (24-255)
        let oneByte = Data([0x18, 0x18]) // 24 encoded with 1 byte
        XCTAssertNoThrow(try decoder.decodeValue(from: oneByte))

        // 2-byte encoding (256-65535)
        let twoBytes = Data([0x19, 0x01, 0x00]) // 256 encoded with 2 bytes
        XCTAssertNoThrow(try decoder.decodeValue(from: twoBytes))

        // 4-byte encoding (65536-4294967295)
        let fourBytes = Data([0x1A, 0x00, 0x01, 0x00, 0x00]) // 65536 encoded with 4 bytes
        XCTAssertNoThrow(try decoder.decodeValue(from: fourBytes))

        // 8-byte encoding (4294967296+)
        let eightBytes = Data([0x1B, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]) // 4294967296 encoded with 8 bytes
        XCTAssertNoThrow(try decoder.decodeValue(from: eightBytes))
    }

    // MARK: - Negative Integer Encoding Tests

    func testRejectNonCanonicalNegativeIntegers() throws {
        // -10 encoded as 2-byte negative integer (should be direct)
        let data = Data([0x38, 0x09]) // Major type 1, additional byte with value 9 (encodes -10)

        XCTAssertThrowsError(try decoder.decodeValue(from: data)) { error in
            guard case CBORError.invalidFormat(let msg) = error else {
                XCTFail("Expected invalidFormat error for non-canonical negative encoding")
                return
            }
            XCTAssertTrue(msg.contains("Non-canonical") || msg.contains("should use direct"))
        }
    }

    // MARK: - Length Encoding Tests for Strings/Arrays/Maps

    func testRejectNonCanonicalStringLength() throws {
        // Text string with length 10 encoded as 2-byte length (should be direct)
        let data = Data([0x78, 0x0A]) + Data("helloworld".utf8) // Major type 3, 1-byte length encoding

        XCTAssertThrowsError(try decoder.decodeValue(from: data)) { error in
            guard case CBORError.invalidFormat(let msg) = error else {
                XCTFail("Expected invalidFormat error for non-canonical string length")
                return
            }
            XCTAssertTrue(msg.contains("Non-canonical") || msg.contains("should use direct"))
        }
    }

    func testRejectNonCanonicalArrayLength() throws {
        // Array with 5 elements encoded with 1-byte length (should be direct)
        var data = Data([0x98, 0x05]) // Major type 4, 1-byte length encoding
        // Add 5 elements
        for i in 0..<5 {
            data.append(UInt8(i))
        }

        XCTAssertThrowsError(try decoder.decodeValue(from: data)) { error in
            guard case CBORError.invalidFormat(let msg) = error else {
                XCTFail("Expected invalidFormat error for non-canonical array length")
                return
            }
            XCTAssertTrue(msg.contains("Non-canonical") || msg.contains("should use direct"))
        }
    }

    // MARK: - Non-Strict Mode Tests

    func testNonStrictModeAcceptsNonCanonical() throws {
        // Disable strict mode
        decoder.options.strictMode = false

        // Non-canonical encodings should be accepted
        let nonCanonical1 = Data([0x18, 0x0A]) // 10 as 1-byte
        XCTAssertNoThrow(try decoder.decodeValue(from: nonCanonical1))

        let nonCanonical2 = Data([0x19, 0x00, 0xFF]) // 255 as 2-byte
        XCTAssertNoThrow(try decoder.decodeValue(from: nonCanonical2))

        let nonCanonical3 = Data([0x1A, 0x00, 0x00, 0xFF, 0xFF]) // 65535 as 4-byte
        XCTAssertNoThrow(try decoder.decodeValue(from: nonCanonical3))
    }

    // MARK: - Indefinite-Length Validation Tests

    func testStrictModeValidatesIndefiniteByteStringChunks() throws {
        // Create an indefinite byte string with a text string chunk (invalid)
        let data = Data([
            0x5F, // Start indefinite byte string
            0x61, 0x41, // Text string "A" (wrong type for byte string chunk!)
            0xFF  // Break
        ])

        // Both strict and non-strict modes should reject wrong chunk type
        XCTAssertThrowsError(try decoder.decodeValue(from: data)) { error in
            guard case CBORError.wrongTypeInsideIndefiniteLength = error else {
                XCTFail("Expected wrongTypeInsideIndefiniteLength error")
                return
            }
        }

        // Non-strict mode should also reject this
        decoder.options.strictMode = false
        XCTAssertThrowsError(try decoder.decodeValue(from: data)) { error in
            guard case CBORError.wrongTypeInsideIndefiniteLength = error else {
                XCTFail("Expected wrongTypeInsideIndefiniteLength error")
                return
            }
        }
    }

    func testStrictModeAcceptsValidIndefiniteByteString() throws {
        // Create a valid indefinite byte string with definite-length chunks
        let data = Data([
            0x5F, // Start indefinite byte string
            0x43, 0x01, 0x02, 0x03, // 3-byte chunk
            0x42, 0x04, 0x05, // 2-byte chunk
            0xFF  // Break
        ])

        let result = try decoder.decodeValue(from: data)
        guard case .byteString(let bytes) = result else {
            XCTFail("Expected byte string")
            return
        }
        XCTAssertEqual(bytes, Data([0x01, 0x02, 0x03, 0x04, 0x05]))
    }

    // MARK: - Performance Comparison

    func testStrictModePerformance() throws {
        // Create test data with many integers
        var data = Data([0x9F]) // Indefinite array
        for i in 0..<1000 {
            if i < 24 {
                data.append(UInt8(i))
            } else if i < 256 {
                data.append(contentsOf: [0x18, UInt8(i)])
            } else {
                data.append(contentsOf: [0x19, UInt8(i >> 8), UInt8(i & 0xFF)])
            }
        }
        data.append(0xFF) // Break

        // Measure strict mode performance
        decoder.options.strictMode = true
        measure {
            _ = try? decoder.decodeValue(from: data)
        }
    }
}