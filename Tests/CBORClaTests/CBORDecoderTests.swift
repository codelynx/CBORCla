import XCTest
@testable import CBORCla

final class CBORDecoderTests: XCTestCase {
    var decoder: CBORDecoder!

    override func setUp() {
        super.setUp()
        decoder = CBORDecoder()
    }

    func testDecodeUnsignedIntegers() throws {
        XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x00])), 0)
        XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x01])), 1)
        XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x0a])), 10)
        XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x17])), 23)
        XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x18, 0x18])), 24)
        XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x18, 0x19])), 25)
        XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x18, 0x64])), 100)
        XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x19, 0x03, 0xe8])), 1000)
        XCTAssertEqual(try decoder.decode(UInt.self, from: Data([0x1a, 0x00, 0x0f, 0x42, 0x40])), 1000000)
        XCTAssertEqual(try decoder.decode(UInt64.self, from: Data([0x1b, 0x00, 0x00, 0x00, 0xe8, 0xd4, 0xa5, 0x10, 0x00])), 1000000000000)
    }

    func testDecodeNegativeIntegers() throws {
        XCTAssertEqual(try decoder.decode(Int.self, from: Data([0x20])), -1)
        XCTAssertEqual(try decoder.decode(Int.self, from: Data([0x29])), -10)
        XCTAssertEqual(try decoder.decode(Int.self, from: Data([0x38, 0x63])), -100)
        XCTAssertEqual(try decoder.decode(Int.self, from: Data([0x39, 0x03, 0xe7])), -1000)
    }

    func testDecodeStrings() throws {
        XCTAssertEqual(try decoder.decode(String.self, from: Data([0x60])), "")
        XCTAssertEqual(try decoder.decode(String.self, from: Data([0x61, 0x61])), "a")
        XCTAssertEqual(try decoder.decode(String.self, from: Data([0x64, 0x49, 0x45, 0x54, 0x46])), "IETF")
        XCTAssertEqual(try decoder.decode(String.self, from: Data([0x62, 0x22, 0x5c])), "\"\\")
        XCTAssertEqual(try decoder.decode(String.self, from: Data([0x62, 0xc3, 0xbc])), "\u{00fc}")
        XCTAssertEqual(try decoder.decode(String.self, from: Data([0x63, 0xe6, 0xb0, 0xb4])), "\u{6c34}")
    }

    func testDecodeBooleans() throws {
        XCTAssertEqual(try decoder.decode(Bool.self, from: Data([0xf4])), false)
        XCTAssertEqual(try decoder.decode(Bool.self, from: Data([0xf5])), true)
    }

    func testDecodeNull() throws {
        struct NullableStruct: Decodable {
            let value: String?
        }
        let data = Data([0xa1, 0x65, 0x76, 0x61, 0x6c, 0x75, 0x65, 0xf6])
        let result = try decoder.decode(NullableStruct.self, from: data)
        XCTAssertNil(result.value)
    }

    func testDecodeFloats() throws {
        XCTAssertEqual(try decoder.decode(Float.self, from: Data([0xfa, 0x00, 0x00, 0x00, 0x00])), 0.0)
        XCTAssertEqual(try decoder.decode(Float.self, from: Data([0xfa, 0x80, 0x00, 0x00, 0x00])), -0.0)
        XCTAssertEqual(try decoder.decode(Float.self, from: Data([0xfa, 0x3f, 0x80, 0x00, 0x00])), 1.0)
        XCTAssertEqual(try decoder.decode(Float.self, from: Data([0xfa, 0x3f, 0xc0, 0x00, 0x00])), 1.5)
        XCTAssertEqual(try decoder.decode(Float.self, from: Data([0xfa, 0x47, 0xc3, 0x50, 0x00])), 100000.0)
        XCTAssertEqual(try decoder.decode(Float.self, from: Data([0xfa, 0x7f, 0x80, 0x00, 0x00])), Float.infinity)
        XCTAssertEqual(try decoder.decode(Float.self, from: Data([0xfa, 0xff, 0x80, 0x00, 0x00])), -Float.infinity)
    }

    func testDecodeDoubles() throws {
        XCTAssertEqual(try decoder.decode(Double.self, from: Data([0xfb, 0x3f, 0xf1, 0x99, 0x99, 0x99, 0x99, 0x99, 0x9a])), 1.1, accuracy: 0.0000001)
        XCTAssertEqual(try decoder.decode(Double.self, from: Data([0xfb, 0xc0, 0x10, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66])), -4.1, accuracy: 0.0000001)
        XCTAssertEqual(try decoder.decode(Double.self, from: Data([0xfb, 0x7f, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])), Double.infinity)
        XCTAssertEqual(try decoder.decode(Double.self, from: Data([0xfb, 0xff, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])), -Double.infinity)
    }

    func testDecodeArrays() throws {
        XCTAssertEqual(try decoder.decode([Int].self, from: Data([0x80])), [])
        XCTAssertEqual(try decoder.decode([Int].self, from: Data([0x83, 0x01, 0x02, 0x03])), [1, 2, 3])
        XCTAssertEqual(try decoder.decode([[Int]].self, from: Data([0x83, 0x81, 0x01, 0x82, 0x02, 0x03, 0x82, 0x04, 0x05])), [[1], [2, 3], [4, 5]])

        let data25 = Data([0x98, 0x19] + (1...25).flatMap { i -> [UInt8] in
            i < 24 ? [UInt8(i)] : [0x18, UInt8(i)]
        })
        XCTAssertEqual(try decoder.decode([Int].self, from: data25), Array(1...25))
    }

    func testDecodeMaps() throws {
        XCTAssertEqual(try decoder.decode([String: Int].self, from: Data([0xa0])), [:])

        let dict1 = try decoder.decode([String: Int].self, from: Data([0xa2, 0x61, 0x61, 0x01, 0x61, 0x62, 0x02]))
        XCTAssertEqual(dict1, ["a": 1, "b": 2])

        let dict2 = try decoder.decode([String: String].self, from: Data([0xa5, 0x61, 0x61, 0x61, 0x41, 0x61, 0x62, 0x61, 0x42,
                                                                         0x61, 0x63, 0x61, 0x43, 0x61, 0x64, 0x61, 0x44,
                                                                         0x61, 0x65, 0x61, 0x45]))
        XCTAssertEqual(dict2, ["a": "A", "b": "B", "c": "C", "d": "D", "e": "E"])
    }

    func testDecodeCodableStruct() throws {
        struct Person: Decodable, Equatable {
            let name: String
            let age: Int
            let email: String
        }

        let data = Data([0xa3, 0x64, 0x6e, 0x61, 0x6d, 0x65, 0x64, 0x4a, 0x6f, 0x68, 0x6e,
                        0x63, 0x61, 0x67, 0x65, 0x18, 0x1e,
                        0x65, 0x65, 0x6d, 0x61, 0x69, 0x6c, 0x70, 0x6a, 0x6f, 0x68, 0x6e,
                        0x40, 0x65, 0x78, 0x61, 0x6d, 0x70, 0x6c, 0x65, 0x2e, 0x63, 0x6f, 0x6d])

        let person = try decoder.decode(Person.self, from: data)
        XCTAssertEqual(person, Person(name: "John", age: 30, email: "john@example.com"))
    }

    func testDecodeIndefiniteArray() throws {
        let data = Data([0x9f, 0x01, 0x02, 0x03, 0xff])
        let value = try decoder.decodeValue(from: data)
        guard case .array(let array) = value else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(array, [.unsigned(1), .unsigned(2), .unsigned(3)])
    }

    func testDecodeIndefiniteMap() throws {
        let data = Data([0xbf, 0x61, 0x61, 0x01, 0x61, 0x62, 0x02, 0xff])
        let value = try decoder.decodeValue(from: data)
        guard case .map(let map) = value else {
            XCTFail("Expected map")
            return
        }
        XCTAssertEqual(map[CBORKey(.textString("a"))], .unsigned(1))
        XCTAssertEqual(map[CBORKey(.textString("b"))], .unsigned(2))
    }

    func testDecodeIndefiniteByteString() throws {
        let data = Data([0x5f, 0x42, 0x01, 0x02, 0x43, 0x03, 0x04, 0x05, 0xff])
        let value = try decoder.decodeValue(from: data)
        guard case .byteString(let bytes) = value else {
            XCTFail("Expected byte string")
            return
        }
        XCTAssertEqual(bytes, Data([0x01, 0x02, 0x03, 0x04, 0x05]))
    }

    func testDecodeIndefiniteTextString() throws {
        let data = Data([0x7f, 0x65, 0x73, 0x74, 0x72, 0x65, 0x61, 0x64, 0x6d, 0x69, 0x6e, 0x67, 0xff])
        let value = try decoder.decodeValue(from: data)
        guard case .textString(let str) = value else {
            XCTFail("Expected text string")
            return
        }
        XCTAssertEqual(str, "streaming")
    }

    func testDecodeTaggedValue() throws {
        let data = Data([0xc1, 0xfb, 0x41, 0xd4, 0x52, 0xd9, 0xec, 0x20, 0x00, 0x00])
        let value = try decoder.decodeValue(from: data)
        guard case .tagged(let tag, let boxed) = value else {
            XCTFail("Expected tagged value")
            return
        }
        XCTAssertEqual(tag, 1)
        guard case .float64(let timestamp) = boxed.value else {
            XCTFail("Expected float64")
            return
        }
        XCTAssertEqual(timestamp, 1363896240.5, accuracy: 0.1)
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
            (Data([0x0a]), .unsigned(10)),
            (Data([0x17]), .unsigned(23)),
            (Data([0x18, 0x18]), .unsigned(24)),
            (Data([0x18, 0x19]), .unsigned(25)),
            (Data([0x18, 0x64]), .unsigned(100)),
            (Data([0x19, 0x03, 0xe8]), .unsigned(1000)),
            (Data([0x1a, 0x00, 0x0f, 0x42, 0x40]), .unsigned(1000000)),
            (Data([0x1b, 0x00, 0x00, 0x00, 0xe8, 0xd4, 0xa5, 0x10, 0x00]), .unsigned(1000000000000)),
            (Data([0x1b, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]), .unsigned(18446744073709551615)),
            (Data([0x20]), .negative(-1)),
            (Data([0x29]), .negative(-10)),
            (Data([0x38, 0x63]), .negative(-100)),
            (Data([0x39, 0x03, 0xe7]), .negative(-1000)),
        ]

        for (data, expected) in testVectors {
            let value = try decoder.decodeValue(from: data)
            XCTAssertEqual(value, expected)
        }
    }
}