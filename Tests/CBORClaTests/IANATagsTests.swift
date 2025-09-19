@testable import CBORCla
import XCTest

final class IANATagsTests: XCTestCase {
	var encoder: CBOREncoder!
	var decoder: CBORDecoder!

	override func setUp() {
		super.setUp()
		encoder = CBOREncoder()
		decoder = CBORDecoder()
	}

	// MARK: - Core CBOR Tags (0-5)

	func testStandardDateTimeTag() throws {
		// Tag 0: RFC3339 date/time string
		let dateString = "2024-09-19T12:34:56Z"

		// Manually encode: tag(0) + text string
		var encoded = Data([0xC0]) // Tag 0
		encoded.append(0x74) // Text string of length 20
		encoded.append(contentsOf: dateString.utf8)

		let decoded = try decoder.decodeValue(from: encoded)
		guard case let .tagged(0, box) = decoded,
		      case let .textString(decodedDate) = box.value
		else {
			XCTFail("Failed to decode tag 0")
			return
		}
		XCTAssertEqual(decodedDate, dateString)
	}

	func testEpochDateTimeTag() throws {
		// Tag 1: Epoch time (seconds since 1970-01-01)
		// Manually encode: tag(1) + float64
		var encoded = Data([0xC1]) // Tag 1
		encoded.append(0xFB) // Float64
		let epochTime = 1_726_749_296.5
		var value = epochTime.bitPattern.bigEndian
		encoded.append(contentsOf: withUnsafeBytes(of: &value, Array.init))

		let decoded = try decoder.decodeValue(from: encoded)
		guard case let .tagged(1, box) = decoded,
		      case let .float64(decodedTime) = box.value
		else {
			XCTFail("Failed to decode tag 1")
			return
		}
		XCTAssertEqual(decodedTime, epochTime, accuracy: 0.01)
	}

	// MARK: - UUID Tag (37)

	func testUUIDTag() throws {
		// Tag 37: Binary UUID (16 bytes)
		let uuid = UUID()
		let uuidBytes = uuid.uuid
		let data = Data([
			uuidBytes.0, uuidBytes.1, uuidBytes.2, uuidBytes.3,
			uuidBytes.4, uuidBytes.5, uuidBytes.6, uuidBytes.7,
			uuidBytes.8, uuidBytes.9, uuidBytes.10, uuidBytes.11,
			uuidBytes.12, uuidBytes.13, uuidBytes.14, uuidBytes.15,
		])

		// Manually encode: tag(37) + byte string
		var encoded = Data([0xD8, 0x25]) // Tag 37
		encoded.append(0x50) // Byte string of length 16
		encoded.append(data)

		let decoded = try decoder.decodeValue(from: encoded)
		guard case let .tagged(37, box) = decoded,
		      case let .byteString(decodedData) = box.value
		else {
			XCTFail("Failed to decode UUID tag")
			return
		}
		XCTAssertEqual(decodedData.count, 16)
		XCTAssertEqual(decodedData, data)
	}

	// MARK: - Language Tagged String (38)

	func testLanguageTaggedString() throws {
		// Tag 38: [language-tag, text]
		let langTag = "en-US"
		let text = "Hello, World!"

		// Manually encode: tag(38) + array with 2 elements
		var encoded = Data([0xD8, 0x26]) // Tag 38
		encoded.append(0x82) // Array with 2 elements
		encoded.append(0x65) // Text string of length 5 (en-US)
		encoded.append(contentsOf: langTag.utf8)
		encoded.append(0x6D) // Text string of length 13 (Hello, World!)
		encoded.append(contentsOf: text.utf8)

		let decoded = try decoder.decodeValue(from: encoded)
		guard case let .tagged(38, box) = decoded,
		      case let .array(arr) = box.value,
		      arr.count == 2,
		      case let .textString(decodedLang) = arr[0],
		      case let .textString(decodedText) = arr[1]
		else {
			XCTFail("Failed to decode language-tagged string")
			return
		}

		XCTAssertEqual(decodedLang, langTag)
		XCTAssertEqual(decodedText, text)
	}

	// MARK: - Network Address Tags (260)

	func testIPv4Tag() throws {
		// Tag 260: IPv4 address (4 bytes)
		let ipv4 = Data([192, 168, 1, 1]) // 192.168.1.1

		// Manually encode: tag(260) + byte string
		var encoded = Data([0xD9, 0x01, 0x04]) // Tag 260
		encoded.append(0x44) // Byte string of length 4
		encoded.append(ipv4)

		let decoded = try decoder.decodeValue(from: encoded)
		guard case let .tagged(260, box) = decoded,
		      case let .byteString(decodedIP) = box.value
		else {
			XCTFail("Failed to decode IPv4 tag")
			return
		}
		XCTAssertEqual(decodedIP, ipv4)
	}

	func testIPv6Tag() throws {
		// Tag 260: IPv6 address (16 bytes)
		let ipv6 = Data(repeating: 0, count: 15) + Data([1]) // ::1

		// Manually encode: tag(260) + byte string
		var encoded = Data([0xD9, 0x01, 0x04]) // Tag 260
		encoded.append(0x50) // Byte string of length 16
		encoded.append(ipv6)

		let decoded = try decoder.decodeValue(from: encoded)
		guard case let .tagged(260, box) = decoded,
		      case let .byteString(decodedIP) = box.value
		else {
			XCTFail("Failed to decode IPv6 tag")
			return
		}
		XCTAssertEqual(decodedIP.count, 16)
	}

	// MARK: - Typed Arrays (64)

	func testTypedArrayTags() throws {
		// Tag 64: Uint8Array
		let uint8Data = Data([0, 1, 2, 3, 255])

		// Manually encode: tag(64) + byte string
		var encoded = Data([0xD8, 0x40]) // Tag 64
		encoded.append(0x45) // Byte string of length 5
		encoded.append(uint8Data)

		let decoded = try decoder.decodeValue(from: encoded)
		guard case let .tagged(64, box) = decoded,
		      case let .byteString(decodedData) = box.value
		else {
			XCTFail("Failed to decode Uint8Array tag")
			return
		}
		XCTAssertEqual(decodedData, uint8Data)
	}

	// MARK: - Time Extensions (100)

	func testDaysSinceEpochTag() throws {
		// Tag 100: Days since 1970-01-01
		let days: UInt64 = 19985 // Approximately Sept 2024

		// Manually encode: tag(100) + unsigned integer
		var encoded = Data([0xD8, 0x64]) // Tag 100
		encoded.append(0x19) // Unsigned 2-byte integer
		encoded.append(0x4E) // 19985 high byte
		encoded.append(0x11) // 19985 low byte

		let decoded = try decoder.decodeValue(from: encoded)
		guard case let .tagged(100, box) = decoded,
		      case let .unsigned(decodedDays) = box.value
		else {
			XCTFail("Failed to decode days since epoch tag")
			return
		}
		XCTAssertEqual(decodedDays, days)
	}

	// MARK: - Self-Described CBOR (55799)

	func testSelfDescribedCBOR() throws {
		// Tag 55799: Self-described CBOR
		let text = "self-described"

		// Manually encode: tag(55799) + text string
		var encoded = Data([0xD9, 0xD9, 0xF7]) // Tag 55799
		encoded.append(0x6E) // Text string of length 14
		encoded.append(contentsOf: text.utf8)

		// Check for magic bytes
		XCTAssertEqual(encoded[0], 0xD9)
		XCTAssertEqual(encoded[1], 0xD9)
		XCTAssertEqual(encoded[2], 0xF7)

		let decoded = try decoder.decodeValue(from: encoded)
		guard case let .tagged(55799, box) = decoded,
		      case let .textString(decodedText) = box.value
		else {
			XCTFail("Failed to decode self-described CBOR")
			return
		}
		XCTAssertEqual(decodedText, text)
	}

	// MARK: - Validation Tests with Strict Mode

	func testStrictModeValidation() throws {
		decoder.options.strictMode = true

		// Test invalid UUID (wrong length)
		var invalidUUID = Data([0xD8, 0x25]) // Tag 37
		invalidUUID.append(0x43) // Byte string of length 3 (should be 16)
		invalidUUID.append(contentsOf: [1, 2, 3])

		XCTAssertThrowsError(try decoder.decodeValue(from: invalidUUID)) { error in
			guard case let CBORError.invalidFormat(msg) = error else {
				XCTFail("Expected invalidFormat error for wrong UUID length")
				return
			}
			XCTAssertTrue(msg.contains("16"))
		}

		// Test invalid network address (wrong length)
		var invalidIP = Data([0xD9, 0x01, 0x04]) // Tag 260
		invalidIP.append(0x42) // Byte string of length 2 (should be 4 or 16)
		invalidIP.append(contentsOf: [1, 2])

		XCTAssertThrowsError(try decoder.decodeValue(from: invalidIP)) { error in
			guard case let CBORError.invalidFormat(msg) = error else {
				XCTFail("Expected invalidFormat error for wrong IP length")
				return
			}
			XCTAssertTrue(msg.contains("4") || msg.contains("16"))
		}
	}

	// MARK: - Registry Coverage Test

	func testIANARegistryCoverage() {
		// Verify we have definitions for common tags
		XCTAssertNotNil(IANATags.registry[0]) // Standard date/time
		XCTAssertNotNil(IANATags.registry[1]) // Epoch time
		XCTAssertNotNil(IANATags.registry[37]) // UUID
		XCTAssertNotNil(IANATags.registry[100]) // Days since epoch
		XCTAssertNotNil(IANATags.registry[260]) // Network address
		XCTAssertNotNil(IANATags.registry[1001]) // Extended time
		XCTAssertNotNil(IANATags.registry[55799]) // Self-described CBOR

		// Check total coverage
		XCTAssertGreaterThan(IANATags.registry.count, 95, "Should have 95+ IANA tags defined")
	}

	// MARK: - Data Item Validation

	func testDataItemRequirements() {
		// Test various data item requirement validations
		let byteReq = DataItemRequirement.byteString(length: 16)
		XCTAssertTrue(byteReq.validate(.byteString(Data(repeating: 0, count: 16))))
		XCTAssertFalse(byteReq.validate(.byteString(Data(repeating: 0, count: 10))))
		XCTAssertFalse(byteReq.validate(.textString("not bytes")))

		let arrayReq = DataItemRequirement.array(elements: 2)
		XCTAssertTrue(arrayReq.validate(.array([.unsigned(1), .unsigned(2)])))
		XCTAssertFalse(arrayReq.validate(.array([.unsigned(1)])))
		XCTAssertFalse(arrayReq.validate(.map([:])))

		let numericReq = DataItemRequirement.numeric
		XCTAssertTrue(numericReq.validate(.unsigned(42)))
		XCTAssertTrue(numericReq.validate(.negative(-1)))
		XCTAssertTrue(numericReq.validate(.float32(3.14)))
		XCTAssertFalse(numericReq.validate(.textString("42")))
	}
}
