@testable import CBORCla
import XCTest

final class CBOREncoderTests: XCTestCase {
	var encoder: CBOREncoder!

	override func setUp() {
		super.setUp()
		encoder = CBOREncoder()
	}

	func testEncodeUnsignedIntegers() throws {
		XCTAssertEqual(try encoder.encodeToBytes(0), [0x00])
		XCTAssertEqual(try encoder.encodeToBytes(1), [0x01])
		XCTAssertEqual(try encoder.encodeToBytes(10), [0x0A])
		XCTAssertEqual(try encoder.encodeToBytes(23), [0x17])
		XCTAssertEqual(try encoder.encodeToBytes(24), [0x18, 0x18])
		XCTAssertEqual(try encoder.encodeToBytes(25), [0x18, 0x19])
		XCTAssertEqual(try encoder.encodeToBytes(100), [0x18, 0x64])
		XCTAssertEqual(try encoder.encodeToBytes(1000), [0x19, 0x03, 0xE8])
		XCTAssertEqual(try encoder.encodeToBytes(1_000_000), [0x1A, 0x00, 0x0F, 0x42, 0x40])
		XCTAssertEqual(
			try encoder.encodeToBytes(UInt64(1_000_000_000_000)),
			[0x1B, 0x00, 0x00, 0x00, 0xE8, 0xD4, 0xA5, 0x10, 0x00]
		)
	}

	func testEncodeNegativeIntegers() throws {
		XCTAssertEqual(try encoder.encodeToBytes(-1), [0x20])
		XCTAssertEqual(try encoder.encodeToBytes(-10), [0x29])
		XCTAssertEqual(try encoder.encodeToBytes(-100), [0x38, 0x63])
		XCTAssertEqual(try encoder.encodeToBytes(-1000), [0x39, 0x03, 0xE7])
	}

	func testEncodeStrings() throws {
		XCTAssertEqual(try encoder.encodeToBytes(""), [0x60])
		XCTAssertEqual(try encoder.encodeToBytes("a"), [0x61, 0x61])
		XCTAssertEqual(try encoder.encodeToBytes("IETF"), [0x64, 0x49, 0x45, 0x54, 0x46])
		XCTAssertEqual(try encoder.encodeToBytes("\"\\"), [0x62, 0x22, 0x5C])
		XCTAssertEqual(try encoder.encodeToBytes("\u{00fc}"), [0x62, 0xC3, 0xBC])
		XCTAssertEqual(try encoder.encodeToBytes("\u{6c34}"), [0x63, 0xE6, 0xB0, 0xB4])
	}

	func testEncodeBooleans() throws {
		XCTAssertEqual(try encoder.encodeToBytes(false), [0xF4])
		XCTAssertEqual(try encoder.encodeToBytes(true), [0xF5])
	}

	func testEncodeNull() throws {
		struct NullableStruct: Encodable {
			let value: String?

			enum CodingKeys: String, CodingKey {
				case value
			}

			func encode(to encoder: Encoder) throws {
				var container = encoder.container(keyedBy: CodingKeys.self)
				try container.encode(value, forKey: .value)
			}
		}
		let data = try encoder.encode(NullableStruct(value: nil))
		XCTAssertTrue(data.contains(0xF6))
	}

	func testEncodeFloats() throws {
		XCTAssertEqual(try encoder.encodeToBytes(Float(0.0)), [0xFA, 0x00, 0x00, 0x00, 0x00])
		XCTAssertEqual(try encoder.encodeToBytes(Float(-0.0)), [0xFA, 0x80, 0x00, 0x00, 0x00])
		XCTAssertEqual(try encoder.encodeToBytes(Float(1.0)), [0xFA, 0x3F, 0x80, 0x00, 0x00])
		XCTAssertEqual(try encoder.encodeToBytes(Float(1.5)), [0xFA, 0x3F, 0xC0, 0x00, 0x00])
		XCTAssertEqual(try encoder.encodeToBytes(Float(100_000.0)), [0xFA, 0x47, 0xC3, 0x50, 0x00])
		XCTAssertEqual(try encoder.encodeToBytes(Float(3.4028234663852886e+38)), [0xFA, 0x7F, 0x7F, 0xFF, 0xFF])
		XCTAssertEqual(try encoder.encodeToBytes(Float.infinity), [0xFA, 0x7F, 0x80, 0x00, 0x00])
		XCTAssertEqual(try encoder.encodeToBytes(-Float.infinity), [0xFA, 0xFF, 0x80, 0x00, 0x00])
	}

	func testEncodeDoubles() throws {
		XCTAssertEqual(try encoder.encodeToBytes(1.1), [0xFB, 0x3F, 0xF1, 0x99, 0x99, 0x99, 0x99, 0x99, 0x9A])
		XCTAssertEqual(try encoder.encodeToBytes(-4.1), [0xFB, 0xC0, 0x10, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66])
		XCTAssertEqual(
			try encoder.encodeToBytes(Double.infinity),
			[0xFB, 0x7F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
		)
		XCTAssertEqual(
			try encoder.encodeToBytes(-Double.infinity),
			[0xFB, 0xFF, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
		)
	}

	func testEncodeArrays() throws {
		XCTAssertEqual(try encoder.encodeToBytes([Int]()), [0x80])
		XCTAssertEqual(try encoder.encodeToBytes([1, 2, 3]), [0x83, 0x01, 0x02, 0x03])
		XCTAssertEqual(
			try encoder.encodeToBytes([[1], [2, 3], [4, 5]]),
			[0x83, 0x81, 0x01, 0x82, 0x02, 0x03, 0x82, 0x04, 0x05]
		)

		let array25 = Array(1 ... 25)
		var expected: [UInt8] = [0x98, 0x19]
		expected.append(contentsOf: array25.map { UInt8($0 < 24 ? $0 : 0x18) })
		expected.append(contentsOf: array25.compactMap { $0 >= 24 ? UInt8($0) : nil })
		XCTAssertEqual(try encoder.encodeToBytes(array25), expected)
	}

	func testEncodeMaps() throws {
		let emptyDict: [String: Int] = [:]
		XCTAssertEqual(try encoder.encodeToBytes(emptyDict), [0xA0])

		encoder.options.sortKeys = true

		let dict1 = ["a": 1, "b": 2]
		XCTAssertEqual(
			try encoder.encodeToBytes(dict1),
			[0xA2, 0x61, 0x61, 0x01, 0x61, 0x62, 0x02]
		)

		let dict2 = ["a": "A", "b": "B", "c": "C", "d": "D", "e": "E"]
		XCTAssertEqual(
			try encoder.encodeToBytes(dict2),
			[
				0xA5,
				0x61,
				0x61,
				0x61,
				0x41,
				0x61,
				0x62,
				0x61,
				0x42,
				0x61,
				0x63,
				0x61,
				0x43,
				0x61,
				0x64,
				0x61,
				0x44,
				0x61,
				0x65,
				0x61,
				0x45,
			]
		)
	}

	func testEncodeCodableStruct() throws {
		struct Person: Encodable {
			let name: String
			let age: Int
			let email: String
		}

		let person = Person(name: "John", age: 30, email: "john@example.com")
		let data = try encoder.encode(person)

		let decoder = CBORDecoder()
		let value = try decoder.decodeValue(from: data)

		guard case let .map(dict) = value else {
			XCTFail("Expected map")
			return
		}

		XCTAssertEqual(dict[CBORKey(.textString("name"))], .textString("John"))
		XCTAssertEqual(dict[CBORKey(.textString("age"))], .unsigned(30))
		XCTAssertEqual(dict[CBORKey(.textString("email"))], .textString("john@example.com"))
	}

	func testEncodeDateEpochTime() throws {
		let date = Date(timeIntervalSince1970: 1_363_896_240.5)
		encoder.options.dateEncodingStrategy = .epochTime
		let data = try encoder.encode(date)
		XCTAssertEqual(Array(data), [0xFB, 0x41, 0xD4, 0x52, 0xD9, 0xEC, 0x20, 0x00, 0x00])
	}

	func testEncodeDateTagged() throws {
		let date = Date(timeIntervalSince1970: 1_363_896_240.5)
		encoder.options.dateEncodingStrategy = .tagged
		let data = try encoder.encode(date)
		XCTAssertEqual(Array(data), [0xC1, 0xFB, 0x41, 0xD4, 0x52, 0xD9, 0xEC, 0x20, 0x00, 0x00])
	}

	func testEncodeData() throws {
		let bytes: [UInt8] = [0x01, 0x02, 0x03, 0x04]
		let data = Data(bytes)
		encoder.options.dataEncodingStrategy = .byteString
		let encoded = try encoder.encode(data)
		XCTAssertEqual(Array(encoded), [0x44, 0x01, 0x02, 0x03, 0x04])
	}

	func testEncodeComplexNestedStructure() throws {
		let person = Person(
			name: "Alice",
			age: 28,
			address: Address(
				street: "123 Main St",
				city: "New York",
				zipCode: "10001"
			),
			company: Company(
				name: "Tech Corp",
				employees: 500
			),
			hobbies: ["reading", "cycling", "photography"]
		)

		let data = try encoder.encode(person)
		let decoder = CBORDecoder()
		let decodedPerson = try decoder.decode(Person.self, from: data)

		XCTAssertEqual(person.name, decodedPerson.name)
		XCTAssertEqual(person.age, decodedPerson.age)
		XCTAssertEqual(person.address.city, decodedPerson.address.city)
		XCTAssertEqual(person.company.employees, decodedPerson.company.employees)
		XCTAssertEqual(person.hobbies, decodedPerson.hobbies)
	}
}

// Helper extensions for test compilation
struct Address: Codable {
	let street: String
	let city: String
	let zipCode: String
}

struct Company: Codable {
	let name: String
	let employees: Int
}

struct Person: Codable {
	let name: String
	let age: Int
	let address: Address
	let company: Company
	let hobbies: [String]
}
