@testable import CBORCla
import XCTest

final class CBORDecoderTests: XCTestCase {
	var decoder: CBORDecoder!

	override func setUp() {
		super.setUp()
		decoder = CBORDecoder()
	}

	func testDecodeUnsignedIntegers() throws {
		XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x00])), 0)
		XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x01])), 1)
		XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x0A])), 10)
		XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x17])), 23)
		XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x18, 0x18])), 24)
		XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x18, 0x19])), 25)
		XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x18, 0x64])), 100)
		XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x19, 0x03, 0xE8])), 1000)
		XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x1A, 0x00, 0x0F, 0x42, 0x40])), 1_000_000)
		XCTAssertEqual(
			try decoder.decode(UInt64.self, from: Data([0x1B, 0x00, 0x00, 0x00, 0xE8, 0xD4, 0xA5, 0x10, 0x00])),
			1_000_000_000_000
		)
	}

	func testDecodeNegativeIntegers() throws {
		XCTAssertEqual(try decoder.decode(Int.self, from: Data([0x20])), -1)
		XCTAssertEqual(try decoder.decode(Int.self, from: Data([0x29])), -10)
		XCTAssertEqual(try decoder.decode(Int.self, from: Data([0x38, 0x63])), -100)
		XCTAssertEqual(try decoder.decode(Int.self, from: Data([0x39, 0x03, 0xE7])), -1000)
	}

	func testDecodeStrings() throws {
		XCTAssertEqual(try decoder.decode(String.self, from: Data([0x60])), "")
		XCTAssertEqual(try decoder.decode(String.self, from: Data([0x61, 0x61])), "a")
		XCTAssertEqual(try decoder.decode(String.self, from: Data([0x64, 0x49, 0x45, 0x54, 0x46])), "IETF")
		XCTAssertEqual(try decoder.decode(String.self, from: Data([0x62, 0x22, 0x5C])), "\"\\")
		XCTAssertEqual(try decoder.decode(String.self, from: Data([0x62, 0xC3, 0xBC])), "\u{00fc}")
		XCTAssertEqual(try decoder.decode(String.self, from: Data([0x63, 0xE6, 0xB0, 0xB4])), "\u{6c34}")
	}

	func testDecodeBooleans() throws {
		XCTAssertEqual(try decoder.decode(Bool.self, from: Data([0xF4])), false)
		XCTAssertEqual(try decoder.decode(Bool.self, from: Data([0xF5])), true)
	}

	func testDecodeNull() throws {
		struct NullableStruct: Decodable {
			let value: String?
		}
		let data = Data([0xA1, 0x65, 0x76, 0x61, 0x6C, 0x75, 0x65, 0xF6])
		let result = try decoder.decode(NullableStruct.self, from: data)
		XCTAssertNil(result.value)
	}

	func testDecodeFloats() throws {
		XCTAssertEqual(try decoder.decode(Float.self, from: Data([0xFA, 0x00, 0x00, 0x00, 0x00])), 0.0)
		XCTAssertEqual(try decoder.decode(Float.self, from: Data([0xFA, 0x80, 0x00, 0x00, 0x00])), -0.0)
		XCTAssertEqual(try decoder.decode(Float.self, from: Data([0xFA, 0x3F, 0x80, 0x00, 0x00])), 1.0)
		XCTAssertEqual(try decoder.decode(Float.self, from: Data([0xFA, 0x3F, 0xC0, 0x00, 0x00])), 1.5)
		XCTAssertEqual(try decoder.decode(Float.self, from: Data([0xFA, 0x47, 0xC3, 0x50, 0x00])), 100_000.0)
		XCTAssertEqual(try decoder.decode(Float.self, from: Data([0xFA, 0x7F, 0x80, 0x00, 0x00])), Float.infinity)
		XCTAssertEqual(try decoder.decode(Float.self, from: Data([0xFA, 0xFF, 0x80, 0x00, 0x00])), -Float.infinity)
	}

	func testDecodeDoubles() throws {
		XCTAssertEqual(
			try decoder.decode(Double.self, from: Data([0xFB, 0x3F, 0xF1, 0x99, 0x99, 0x99, 0x99, 0x99, 0x9A])),
			1.1,
			accuracy: 0.0000001
		)
		XCTAssertEqual(
			try decoder.decode(Double.self, from: Data([0xFB, 0xC0, 0x10, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66])),
			-4.1,
			accuracy: 0.0000001
		)
		XCTAssertEqual(
			try decoder.decode(Double.self, from: Data([0xFB, 0x7F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])),
			Double.infinity
		)
		XCTAssertEqual(
			try decoder.decode(Double.self, from: Data([0xFB, 0xFF, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])),
			-Double.infinity
		)
	}

	func testDecodeArrays() throws {
		XCTAssertEqual(try decoder.decode([Int].self, from: Data([0x80])), [])
		XCTAssertEqual(try decoder.decode([Int].self, from: Data([0x83, 0x01, 0x02, 0x03])), [1, 2, 3])
		XCTAssertEqual(
			try decoder.decode([[Int]].self, from: Data([0x83, 0x81, 0x01, 0x82, 0x02, 0x03, 0x82, 0x04, 0x05])),
			[[1], [2, 3], [4, 5]]
		)

		let data25 = Data([0x98, 0x19] + (1 ... 25).flatMap { i -> [UInt8] in
			i < 24 ? [UInt8(i)] : [0x18, UInt8(i)]
		})
		XCTAssertEqual(try decoder.decode([Int].self, from: data25), Array(1 ... 25))
	}

	func testDecodeMaps() throws {
		XCTAssertEqual(try decoder.decode([String: Int].self, from: Data([0xA0])), [:])

		let dict1 = try decoder.decode([String: Int].self, from: Data([0xA2, 0x61, 0x61, 0x01, 0x61, 0x62, 0x02]))
		XCTAssertEqual(dict1, ["a": 1, "b": 2])

		let dict2 = try decoder.decode(
			[String: String].self,
			from: Data([
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
			])
		)
		XCTAssertEqual(dict2, ["a": "A", "b": "B", "c": "C", "d": "D", "e": "E"])
	}

	func testDecodeCodableStruct() throws {
		struct Person: Decodable, Equatable {
			let name: String
			let age: Int
			let email: String
		}

		let data = Data([
			0xA3,
			0x64,
			0x6E,
			0x61,
			0x6D,
			0x65,
			0x64,
			0x4A,
			0x6F,
			0x68,
			0x6E,
			0x63,
			0x61,
			0x67,
			0x65,
			0x18,
			0x1E,
			0x65,
			0x65,
			0x6D,
			0x61,
			0x69,
			0x6C,
			0x70,
			0x6A,
			0x6F,
			0x68,
			0x6E,
			0x40,
			0x65,
			0x78,
			0x61,
			0x6D,
			0x70,
			0x6C,
			0x65,
			0x2E,
			0x63,
			0x6F,
			0x6D,
		])

		let person = try decoder.decode(Person.self, from: data)
		XCTAssertEqual(person, Person(name: "John", age: 30, email: "john@example.com"))
	}

	func testDecodeIndefiniteArray() throws {
		let data = Data([0x9F, 0x01, 0x02, 0x03, 0xFF])
		let value = try decoder.decodeValue(from: data)
		guard case let .array(array) = value else {
			XCTFail("Expected array")
			return
		}
		XCTAssertEqual(array, [.unsigned(1), .unsigned(2), .unsigned(3)])
	}

	func testDecodeIndefiniteMap() throws {
		let data = Data([0xBF, 0x61, 0x61, 0x01, 0x61, 0x62, 0x02, 0xFF])
		let value = try decoder.decodeValue(from: data)
		guard case let .map(map) = value else {
			XCTFail("Expected map")
			return
		}
		XCTAssertEqual(map[CBORKey(.textString("a"))], .unsigned(1))
		XCTAssertEqual(map[CBORKey(.textString("b"))], .unsigned(2))
	}

	func testDecodeIndefiniteByteString() throws {
		let data = Data([0x5F, 0x42, 0x01, 0x02, 0x43, 0x03, 0x04, 0x05, 0xFF])
		let value = try decoder.decodeValue(from: data)
		guard case let .byteString(bytes) = value else {
			XCTFail("Expected byte string")
			return
		}
		XCTAssertEqual(bytes, Data([0x01, 0x02, 0x03, 0x04, 0x05]))
	}

	func testDecodeIndefiniteTextString() throws {
		let data = Data([0x7F, 0x65, 0x73, 0x74, 0x72, 0x65, 0x61, 0x64, 0x6D, 0x69, 0x6E, 0x67, 0xFF])
		let value = try decoder.decodeValue(from: data)
		guard case let .textString(str) = value else {
			XCTFail("Expected text string")
			return
		}
		XCTAssertEqual(str, "streaming")
	}

	func testDecodeTaggedValue() throws {
		let data = Data([0xC1, 0xFB, 0x41, 0xD4, 0x52, 0xD9, 0xEC, 0x20, 0x00, 0x00])
		let value = try decoder.decodeValue(from: data)
		guard case let .tagged(tag, boxed) = value else {
			XCTFail("Expected tagged value")
			return
		}
		XCTAssertEqual(tag, 1)
		guard case let .float64(timestamp) = boxed.value else {
			XCTFail("Expected float64")
			return
		}
		XCTAssertEqual(timestamp, 1_363_896_240.5, accuracy: 0.1)
	}

	func testDecodeComplexNestedStructure() throws {
		struct Address: Decodable, Equatable {
			let street: String
			let city: String
			let zipCode: String
		}

		struct Company: Decodable, Equatable {
			let name: String
			let employees: Int
		}

		struct Person: Decodable, Equatable {
			let name: String
			let age: Int
			let address: Address
			let company: Company
			let hobbies: [String]
		}

		let encoder = CBOREncoder()
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

		struct EncodablePerson: Encodable {
			let name: String
			let age: Int
			let address: EncodableAddress
			let company: EncodableCompany
			let hobbies: [String]
		}

		struct EncodableAddress: Encodable {
			let street: String
			let city: String
			let zipCode: String
		}

		struct EncodableCompany: Encodable {
			let name: String
			let employees: Int
		}

		let encodablePerson = EncodablePerson(
			name: person.name,
			age: person.age,
			address: EncodableAddress(
				street: person.address.street,
				city: person.address.city,
				zipCode: person.address.zipCode
			),
			company: EncodableCompany(
				name: person.company.name,
				employees: person.company.employees
			),
			hobbies: person.hobbies
		)

		let data = try encoder.encode(encodablePerson)
		let decodedPerson = try decoder.decode(Person.self, from: data)

		XCTAssertEqual(person, decodedPerson)
	}

	func testDecodeRFC8949TestVectors() throws {
		let testVectors: [(Data, CBORValue)] = [
			(Data([0x00]), .unsigned(0)),
			(Data([0x01]), .unsigned(1)),
			(Data([0x0A]), .unsigned(10)),
			(Data([0x17]), .unsigned(23)),
			(Data([0x18, 0x18]), .unsigned(24)),
			(Data([0x18, 0x19]), .unsigned(25)),
			(Data([0x18, 0x64]), .unsigned(100)),
			(Data([0x19, 0x03, 0xE8]), .unsigned(1000)),
			(Data([0x1A, 0x00, 0x0F, 0x42, 0x40]), .unsigned(1_000_000)),
			(Data([0x1B, 0x00, 0x00, 0x00, 0xE8, 0xD4, 0xA5, 0x10, 0x00]), .unsigned(1_000_000_000_000)),
			(Data([0x1B, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]), .unsigned(18_446_744_073_709_551_615)),
			(Data([0x20]), .negative(-1)),
			(Data([0x29]), .negative(-10)),
			(Data([0x38, 0x63]), .negative(-100)),
			(Data([0x39, 0x03, 0xE7]), .negative(-1000)),
		]

		for (data, expected) in testVectors {
			let value = try decoder.decodeValue(from: data)
			XCTAssertEqual(value, expected)
		}
	}
}
