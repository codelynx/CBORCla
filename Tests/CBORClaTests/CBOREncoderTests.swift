import XCTest
@testable import CBORCla

final class CBOREncoderTests: XCTestCase {
    var encoder: CBOREncoder!

    override func setUp() {
        super.setUp()
        encoder = CBOREncoder()
    }

    func testEncodeUnsignedIntegers() throws {
        XCTAssertEqual(try encoder.encodeToBytes(0), [0x00])
        XCTAssertEqual(try encoder.encodeToBytes(1), [0x01])
        XCTAssertEqual(try encoder.encodeToBytes(10), [0x0a])
        XCTAssertEqual(try encoder.encodeToBytes(23), [0x17])
        XCTAssertEqual(try encoder.encodeToBytes(24), [0x18, 0x18])
        XCTAssertEqual(try encoder.encodeToBytes(25), [0x18, 0x19])
        XCTAssertEqual(try encoder.encodeToBytes(100), [0x18, 0x64])
        XCTAssertEqual(try encoder.encodeToBytes(1000), [0x19, 0x03, 0xe8])
        XCTAssertEqual(try encoder.encodeToBytes(1000000), [0x1a, 0x00, 0x0f, 0x42, 0x40])
        XCTAssertEqual(try encoder.encodeToBytes(UInt64(1000000000000)), [0x1b, 0x00, 0x00, 0x00, 0xe8, 0xd4, 0xa5, 0x10, 0x00])
    }

    func testEncodeNegativeIntegers() throws {
        XCTAssertEqual(try encoder.encodeToBytes(-1), [0x20])
        XCTAssertEqual(try encoder.encodeToBytes(-10), [0x29])
        XCTAssertEqual(try encoder.encodeToBytes(-100), [0x38, 0x63])
        XCTAssertEqual(try encoder.encodeToBytes(-1000), [0x39, 0x03, 0xe7])
    }

    func testEncodeStrings() throws {
        XCTAssertEqual(try encoder.encodeToBytes(""), [0x60])
        XCTAssertEqual(try encoder.encodeToBytes("a"), [0x61, 0x61])
        XCTAssertEqual(try encoder.encodeToBytes("IETF"), [0x64, 0x49, 0x45, 0x54, 0x46])
        XCTAssertEqual(try encoder.encodeToBytes("\"\\"), [0x62, 0x22, 0x5c])
        XCTAssertEqual(try encoder.encodeToBytes("\u{00fc}"), [0x62, 0xc3, 0xbc])
        XCTAssertEqual(try encoder.encodeToBytes("\u{6c34}"), [0x63, 0xe6, 0xb0, 0xb4])
    }

    func testEncodeBooleans() throws {
        XCTAssertEqual(try encoder.encodeToBytes(false), [0xf4])
        XCTAssertEqual(try encoder.encodeToBytes(true), [0xf5])
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
        XCTAssertTrue(data.contains(0xf6))
    }

    func testEncodeFloats() throws {
        XCTAssertEqual(try encoder.encodeToBytes(Float(0.0)), [0xfa, 0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(try encoder.encodeToBytes(Float(-0.0)), [0xfa, 0x80, 0x00, 0x00, 0x00])
        XCTAssertEqual(try encoder.encodeToBytes(Float(1.0)), [0xfa, 0x3f, 0x80, 0x00, 0x00])
        XCTAssertEqual(try encoder.encodeToBytes(Float(1.5)), [0xfa, 0x3f, 0xc0, 0x00, 0x00])
        XCTAssertEqual(try encoder.encodeToBytes(Float(100000.0)), [0xfa, 0x47, 0xc3, 0x50, 0x00])
        XCTAssertEqual(try encoder.encodeToBytes(Float(3.4028234663852886e+38)), [0xfa, 0x7f, 0x7f, 0xff, 0xff])
        XCTAssertEqual(try encoder.encodeToBytes(Float.infinity), [0xfa, 0x7f, 0x80, 0x00, 0x00])
        XCTAssertEqual(try encoder.encodeToBytes(-Float.infinity), [0xfa, 0xff, 0x80, 0x00, 0x00])
    }

    func testEncodeDoubles() throws {
        XCTAssertEqual(try encoder.encodeToBytes(1.1), [0xfb, 0x3f, 0xf1, 0x99, 0x99, 0x99, 0x99, 0x99, 0x9a])
        XCTAssertEqual(try encoder.encodeToBytes(-4.1), [0xfb, 0xc0, 0x10, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66])
        XCTAssertEqual(try encoder.encodeToBytes(Double.infinity), [0xfb, 0x7f, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(try encoder.encodeToBytes(-Double.infinity), [0xfb, 0xff, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    }

    func testEncodeArrays() throws {
        XCTAssertEqual(try encoder.encodeToBytes([Int]()), [0x80])
        XCTAssertEqual(try encoder.encodeToBytes([1, 2, 3]), [0x83, 0x01, 0x02, 0x03])
        XCTAssertEqual(try encoder.encodeToBytes([[1], [2, 3], [4, 5]]),
                      [0x83, 0x81, 0x01, 0x82, 0x02, 0x03, 0x82, 0x04, 0x05])

        let array25 = Array(1...25)
        var expected: [UInt8] = [0x98, 0x19]
        expected.append(contentsOf: array25.map { UInt8($0 < 24 ? $0 : 0x18) })
        expected.append(contentsOf: array25.compactMap { $0 >= 24 ? UInt8($0) : nil })
        XCTAssertEqual(try encoder.encodeToBytes(array25), expected)
    }

    func testEncodeMaps() throws {
        let emptyDict: [String: Int] = [:]
        XCTAssertEqual(try encoder.encodeToBytes(emptyDict), [0xa0])

        encoder.options.sortKeys = true

        let dict1 = ["a": 1, "b": 2]
        XCTAssertEqual(try encoder.encodeToBytes(dict1),
                      [0xa2, 0x61, 0x61, 0x01, 0x61, 0x62, 0x02])

        let dict2 = ["a": "A", "b": "B", "c": "C", "d": "D", "e": "E"]
        XCTAssertEqual(try encoder.encodeToBytes(dict2),
                      [0xa5, 0x61, 0x61, 0x61, 0x41, 0x61, 0x62, 0x61, 0x42,
                       0x61, 0x63, 0x61, 0x43, 0x61, 0x64, 0x61, 0x44,
                       0x61, 0x65, 0x61, 0x45])
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

        guard case .map(let dict) = value else {
            XCTFail("Expected map")
            return
        }

        XCTAssertEqual(dict[CBORKey(.textString("name"))], .textString("John"))
        XCTAssertEqual(dict[CBORKey(.textString("age"))], .unsigned(30))
        XCTAssertEqual(dict[CBORKey(.textString("email"))], .textString("john@example.com"))
    }

    func testEncodeDateEpochTime() throws {
        let date = Date(timeIntervalSince1970: 1363896240.5)
        encoder.options.dateEncodingStrategy = .epochTime
        let data = try encoder.encode(date)
        XCTAssertEqual(Array(data), [0xfb, 0x41, 0xd4, 0x52, 0xd9, 0xec, 0x20, 0x00, 0x00])
    }

    func testEncodeDateTagged() throws {
        let date = Date(timeIntervalSince1970: 1363896240.5)
        encoder.options.dateEncodingStrategy = .tagged
        let data = try encoder.encode(date)
        XCTAssertEqual(Array(data), [0xc1, 0xfb, 0x41, 0xd4, 0x52, 0xd9, 0xec, 0x20, 0x00, 0x00])
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