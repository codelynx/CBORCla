import XCTest
@testable import CBORCla

final class RFC8949ComplianceTests: XCTestCase {
    var encoder: CBOREncoder!
    var decoder: CBORDecoder!

    override func setUp() {
        super.setUp()
        encoder = CBOREncoder()
        decoder = CBORDecoder()
    }

    // MARK: - Canonical Encoding Tests

    func testCanonicalIntegerEncoding() throws {
        encoder.options.useCanonicalEncoding = true

        // Test that integers use shortest possible encoding
        XCTAssertEqual(try encoder.encodeToBytes(0), [0x00])
        XCTAssertEqual(try encoder.encodeToBytes(23), [0x17])
        XCTAssertEqual(try encoder.encodeToBytes(24), [0x18, 0x18])
        XCTAssertEqual(try encoder.encodeToBytes(255), [0x18, 0xff])
        XCTAssertEqual(try encoder.encodeToBytes(256), [0x19, 0x01, 0x00])
        XCTAssertEqual(try encoder.encodeToBytes(65535), [0x19, 0xff, 0xff])
        XCTAssertEqual(try encoder.encodeToBytes(65536), [0x1a, 0x00, 0x01, 0x00, 0x00])
    }

    func testCanonicalFloatEncoding() throws {
        encoder.options.useCanonicalEncoding = true

        // NaN should encode as 0xf97e00
        let nan = Float.nan
        XCTAssertEqual(try encoder.encodeToBytes(nan), [0xf9, 0x7e, 0x00])

        // Infinity should use shortest form
        XCTAssertEqual(try encoder.encodeToBytes(Float.infinity), [0xf9, 0x7c, 0x00])
        XCTAssertEqual(try encoder.encodeToBytes(-Float.infinity), [0xf9, 0xfc, 0x00])

        // Values representable as Float16 should use Float16
        XCTAssertEqual(try encoder.encodeToBytes(Float(0.0)), [0xf9, 0x00, 0x00])
        XCTAssertEqual(try encoder.encodeToBytes(Float(1.0)), [0xf9, 0x3c, 0x00])
        XCTAssertEqual(try encoder.encodeToBytes(Float(-1.0)), [0xf9, 0xbc, 0x00])
    }

    func testCanonicalMapKeyOrdering() throws {
        encoder.options.useCanonicalEncoding = true

        // Keys should be sorted by encoded length first, then lexicographically
        let map: [String: Int] = [
            "aa": 1,
            "b": 2,
            "aaa": 3,
            "z": 4
        ]

        let data = try encoder.encode(map)
        let decoded = try decoder.decodeValue(from: data)

        guard case .map(let decodedMap) = decoded else {
            XCTFail("Expected map")
            return
        }

        // Extract keys in order
        let keys = decodedMap.keys.compactMap { key -> String? in
            guard case .textString(let str) = key.value else { return nil }
            return str
        }

        // Keys should be ordered: "b", "z" (length 1), then "aa" (length 2), then "aaa" (length 3)
        // When encoded, the actual byte order matters
        // We'll verify the encoded bytes follow canonical ordering
        let bytes = Array(data)

        // Map with 4 entries
        XCTAssertEqual(bytes[0], 0xa4)

        // First key should be "b" (shortest that comes first lexicographically among length-1 keys)
        XCTAssertEqual(bytes[1], 0x61) // text string length 1
        XCTAssertEqual(bytes[2], 0x62) // 'b'
    }

    // MARK: - Duplicate Key Detection Tests

    func testDuplicateKeyDetection() throws {
        // Create CBOR with duplicate keys manually
        let duplicateKeyData = Data([
            0xa2, // map with 2 entries
            0x61, 0x61, // "a"
            0x01, // 1
            0x61, 0x61, // "a" again (duplicate)
            0x02  // 2
        ])

        // Should throw error by default (allowDuplicateMapKeys = false)
        XCTAssertThrowsError(try decoder.decodeValue(from: duplicateKeyData)) { error in
            guard case CBORError.duplicateMapKey = error else {
                XCTFail("Expected duplicateMapKey error, got \(error)")
                return
            }
        }

        // Should not throw when duplicates are allowed
        decoder.options.allowDuplicateMapKeys = true
        XCTAssertNoThrow(try decoder.decodeValue(from: duplicateKeyData))
    }

    func testIndefiniteDuplicateKeyDetection() throws {
        // Create indefinite map with duplicate keys
        let duplicateKeyData = Data([
            0xbf, // indefinite map
            0x61, 0x61, // "a"
            0x01, // 1
            0x61, 0x61, // "a" again (duplicate)
            0x02, // 2
            0xff  // break
        ])

        // Should throw error by default
        XCTAssertThrowsError(try decoder.decodeValue(from: duplicateKeyData)) { error in
            guard case CBORError.duplicateMapKey = error else {
                XCTFail("Expected duplicateMapKey error, got \(error)")
                return
            }
        }
    }

    // MARK: - Well-formedness Tests

    func testDepthLimitProtection() throws {
        // Create deeply nested structure
        var data = Data()
        // Add 600 nested arrays (exceeds default depth limit of 512)
        for _ in 0..<600 {
            data.append(0x81) // array with 1 element
        }
        data.append(0x00) // unsigned(0) as the innermost value

        XCTAssertThrowsError(try decoder.decodeValue(from: data)) { error in
            guard case CBORError.depthLimitExceeded = error else {
                XCTFail("Expected depthLimitExceeded error, got \(error)")
                return
            }
        }
    }

    func testUTF8Validation() throws {
        // Invalid UTF-8 sequence
        let invalidUTF8 = Data([
            0x62, // text string length 2
            0xFF, 0xFE  // Invalid UTF-8 bytes
        ])

        XCTAssertThrowsError(try decoder.decodeValue(from: invalidUTF8)) { error in
            guard case CBORError.incorrectUTF8String = error else {
                XCTFail("Expected incorrectUTF8String error, got \(error)")
                return
            }
        }
    }

    // MARK: - Nested Container Tests

    func testNestedContainerEncoding() throws {
        struct Parent: Encodable {
            let name: String
            let child: Child

            struct Child: Encodable {
                let value: Int
            }
        }

        let parent = Parent(name: "parent", child: Parent.Child(value: 42))
        XCTAssertNoThrow(try encoder.encode(parent))

        let data = try encoder.encode(parent)
        let decoded = try decoder.decodeValue(from: data)

        guard case .map(let map) = decoded else {
            XCTFail("Expected map")
            return
        }

        // Verify structure
        guard case .textString("parent") = map[CBORKey(.textString("name"))] else {
            XCTFail("Expected parent name")
            return
        }

        guard case .map(let childMap) = map[CBORKey(.textString("child"))] else {
            XCTFail("Expected child map")
            return
        }

        guard case .unsigned(42) = childMap[CBORKey(.textString("value"))] else {
            XCTFail("Expected child value")
            return
        }
    }
}