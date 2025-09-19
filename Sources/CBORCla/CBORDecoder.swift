import Foundation

public class CBORDecoder {
    public struct Options {
        public var dateDecodingStrategy: DateDecodingStrategy = .epochTime
        public var dataDecodingStrategy: DataDecodingStrategy = .byteString
        public var nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy = .convertFromString
        public var keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys
        public var userInfo: [CodingUserInfoKey: Any] = [:]
        public var allowDuplicateMapKeys: Bool = false
        public var maxDepth: Int = 512
        public var strictMode: Bool = false  // RFC 8949 strict validation mode

        public init() {}
    }

    public enum DateDecodingStrategy {
        case epochTime
        case tagged
        case iso8601String
        case custom((Decoder) throws -> Date)
    }

    public enum DataDecodingStrategy {
        case byteString
        case base64String
        case custom((Decoder) throws -> Data)
    }

    public enum NonConformingFloatDecodingStrategy {
        case convertFromString
        case `throw`
    }

    public enum KeyDecodingStrategy {
        case useDefaultKeys
        case convertFromSnakeCase
        case custom(([CodingKey]) -> CodingKey)
    }

    public var options = Options()

    public init() {}

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = try _CBORDecoder(data: Array(data), options: options)
        return try T(from: decoder)
    }

    public func decodeValue(from data: Data) throws -> CBORValue {
        let reader = CBORReader(bytes: Array(data), allowDuplicateMapKeys: options.allowDuplicateMapKeys, strictMode: options.strictMode)
        return try reader.readValue()
    }
}

final class CBORReader {
    private let bytes: [UInt8]
    private var index: Int = 0
    private var depth: Int = 0
    private let maxDepth: Int = 512
    let allowDuplicateMapKeys: Bool
    let strictMode: Bool

    init(bytes: [UInt8], allowDuplicateMapKeys: Bool = false, strictMode: Bool = false) {
        self.bytes = bytes
        self.allowDuplicateMapKeys = allowDuplicateMapKeys
        self.strictMode = strictMode
    }

    func readValue() throws -> CBORValue {
        guard index < bytes.count else {
            throw CBORError.unexpectedEnd
        }

        depth += 1
        defer { depth -= 1 }

        if depth > maxDepth {
            throw CBORError.depthLimitExceeded
        }

        let byte = bytes[index]
        index += 1

        let majorType = CBORMajorType(rawValue: byte >> 5)!
        let additionalInfo = byte & 0x1f

        switch majorType {
        case .unsigned:
            let value = try readLength(additionalInfo)
            return .unsigned(value)

        case .negative:
            let value = try readLength(additionalInfo)
            return .negative(Int64(bitPattern: ~value))

        case .byteString:
            if additionalInfo == 31 {
                return try readIndefiniteByteString()
            }
            let length = try readLength(additionalInfo)
            return .byteString(try readData(Int(length)))

        case .textString:
            if additionalInfo == 31 {
                return try readIndefiniteTextString()
            }
            let length = try readLength(additionalInfo)
            let data = try readData(Int(length))
            guard let string = String(data: data, encoding: .utf8) else {
                throw CBORError.incorrectUTF8String
            }
            return .textString(string)

        case .array:
            if additionalInfo == 31 {
                return try readIndefiniteArray()
            }
            let length = try readLength(additionalInfo)
            var array = [CBORValue]()
            for _ in 0..<length {
                array.append(try readValue())
            }
            return .array(array)

        case .map:
            if additionalInfo == 31 {
                return try readIndefiniteMap()
            }
            let length = try readLength(additionalInfo)
            var map = [CBORKey: CBORValue]()
            var seenKeys = Set<CBORKey>()
            for _ in 0..<length {
                let key = try readValue()
                let cborKey = CBORKey(key)

                // Check for duplicate keys
                if !allowDuplicateMapKeys && seenKeys.contains(cborKey) {
                    throw CBORError.duplicateMapKey
                }
                seenKeys.insert(cborKey)

                let value = try readValue()
                map[cborKey] = value
            }
            return .map(map)

        case .tag:
            let tag = try readLength(additionalInfo)
            let value = try readValue()

            // Validate tag content according to RFC 8949
            try validateTagContent(tag: tag, value: value)

            return .tagged(tag, Box(value))

        case .primitive:
            switch additionalInfo {
            case 20:
                return .simple(.false)
            case 21:
                return .simple(.true)
            case 22:
                return .simple(.null)
            case 23:
                return .simple(.undefined)
            case 24:
                guard index < bytes.count else {
                    throw CBORError.unexpectedEnd
                }
                let value = bytes[index]
                index += 1

                // RFC 8949: Simple values 0-19 are unassigned and MUST NOT be used
                if value < 20 {
                    throw CBORError.invalidFormat("Unassigned simple value \(value) (0-19 are reserved)")
                }

                if let simple = CBORValue.SimpleValue(rawValue: value) {
                    return .simple(simple)
                }
                // Values 24-31 are reserved
                if value >= 24 && value <= 31 {
                    throw CBORError.invalidFormat("Reserved simple value: \(value)")
                }
                throw CBORError.invalidFormat("Unknown simple value: \(value)")
            case 25:
                let bits = try readUInt16()
                return .float16(Float16(bitPattern: bits))
            case 26:
                let bits = try readUInt32()
                return .float32(Float(bitPattern: bits))
            case 27:
                let bits = try readUInt64()
                return .float64(Double(bitPattern: bits))
            case 31:
                return .break
            default:
                // RFC 8949: Simple values 0-19 are unassigned and MUST NOT be used
                if additionalInfo < 20 {
                    throw CBORError.invalidFormat("Unassigned simple value: \(additionalInfo) (0-19 are reserved)")
                }
                throw CBORError.invalidFormat("Unknown primitive: \(additionalInfo)")
            }
        }
    }

    private func readLength(_ info: UInt8) throws -> UInt64 {
        switch info {
        case 0..<24:
            return UInt64(info)
        case 24:
            let value = try readUInt8()
            // In strict mode, reject non-canonical encodings
            if strictMode && value < 24 {
                throw CBORError.invalidFormat("Non-canonical encoding: value \(value) should use direct encoding")
            }
            return UInt64(value)
        case 25:
            let value = try readUInt16()
            // In strict mode, reject non-canonical encodings
            if strictMode && value <= 0xFF {
                throw CBORError.invalidFormat("Non-canonical encoding: value \(value) should use shorter form")
            }
            return UInt64(value)
        case 26:
            let value = try readUInt32()
            // In strict mode, reject non-canonical encodings
            if strictMode && value <= 0xFFFF {
                throw CBORError.invalidFormat("Non-canonical encoding: value \(value) should use shorter form")
            }
            return UInt64(value)
        case 27:
            let value = try readUInt64()
            // In strict mode, reject non-canonical encodings
            if strictMode && value <= 0xFFFFFFFF {
                throw CBORError.invalidFormat("Non-canonical encoding: value \(value) should use shorter form")
            }
            return value
        default:
            throw CBORError.invalidFormat("Invalid additional info: \(info)")
        }
    }

    private func readUInt8() throws -> UInt8 {
        guard index < bytes.count else {
            throw CBORError.unexpectedEnd
        }
        let value = bytes[index]
        index += 1
        return value
    }

    private func readUInt16() throws -> UInt16 {
        guard index + 1 < bytes.count else {
            throw CBORError.unexpectedEnd
        }
        let value = UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1])
        index += 2
        return value
    }

    private func readUInt32() throws -> UInt32 {
        guard index + 3 < bytes.count else {
            throw CBORError.unexpectedEnd
        }
        let value = UInt32(bytes[index]) << 24 |
                   UInt32(bytes[index + 1]) << 16 |
                   UInt32(bytes[index + 2]) << 8 |
                   UInt32(bytes[index + 3])
        index += 4
        return value
    }

    private func readUInt64() throws -> UInt64 {
        guard index + 7 < bytes.count else {
            throw CBORError.unexpectedEnd
        }
        let value = UInt64(bytes[index]) << 56 |
                   UInt64(bytes[index + 1]) << 48 |
                   UInt64(bytes[index + 2]) << 40 |
                   UInt64(bytes[index + 3]) << 32 |
                   UInt64(bytes[index + 4]) << 24 |
                   UInt64(bytes[index + 5]) << 16 |
                   UInt64(bytes[index + 6]) << 8 |
                   UInt64(bytes[index + 7])
        index += 8
        return value
    }

    private func readData(_ length: Int) throws -> Data {
        guard index + length <= bytes.count else {
            throw CBORError.unexpectedEnd
        }
        let data = Data(bytes[index..<index + length])
        index += length
        return data
    }

    private func readIndefiniteByteString() throws -> CBORValue {
        var chunks = Data()
        var chunkCount = 0
        let maxChunks = 1000000 // Prevent DoS attacks

        while true {
            let value = try readValue()
            if case .break = value {
                break
            }
            guard case .byteString(let data) = value else {
                throw CBORError.wrongTypeInsideIndefiniteLength
            }

            chunkCount += 1
            if chunkCount > maxChunks {
                throw CBORError.tooLongIndefiniteLength
            }

            // Check for overflow
            if chunks.count > Int.max - data.count {
                throw CBORError.malformedData("Byte string too large")
            }

            chunks.append(data)
        }
        return .byteString(chunks)
    }

    private func readIndefiniteTextString() throws -> CBORValue {
        var result = ""
        var chunkCount = 0
        let maxChunks = 1000000 // Prevent DoS attacks

        while true {
            let value = try readValue()
            if case .break = value {
                break
            }
            guard case .textString(let string) = value else {
                throw CBORError.wrongTypeInsideIndefiniteLength
            }

            chunkCount += 1
            if chunkCount > maxChunks {
                throw CBORError.tooLongIndefiniteLength
            }

            // Check for overflow
            if result.count > Int.max - string.count {
                throw CBORError.malformedData("Text string too large")
            }

            result += string
        }
        return .textString(result)
    }

    private func readIndefiniteArray() throws -> CBORValue {
        var array = [CBORValue]()
        while true {
            let value = try readValue()
            if case .break = value {
                break
            }
            array.append(value)
        }
        return .array(array)
    }

    private func validateTagContent(tag: UInt64, value: CBORValue) throws {
        // RFC 8949 and IANA tag content validation
        switch tag {
        case 0: // Standard date/time string (RFC 3339)
            guard case .textString = value else {
                throw CBORError.invalidFormat("Tag 0 requires text string, got \(value)")
            }

        case 1: // Epoch-based date/time
            switch value {
            case .unsigned, .negative, .float16, .float32, .float64:
                break // Valid
            default:
                throw CBORError.invalidFormat("Tag 1 requires numeric value, got \(value)")
            }

        case 2, 3: // Positive/negative bignum
            guard case .byteString = value else {
                throw CBORError.invalidFormat("Tag \(tag) requires byte string, got \(value)")
            }

        case 4, 5: // Decimal fraction / Bigfloat
            guard case .array(let arr) = value, arr.count == 2 else {
                throw CBORError.invalidFormat("Tag \(tag) requires array with 2 elements")
            }
            // First element must be exponent (integer)
            switch arr[0] {
            case .unsigned, .negative:
                break
            default:
                throw CBORError.invalidFormat("Tag \(tag) exponent must be integer")
            }
            // Second element must be mantissa (integer or bignum for tag 4, any number for tag 5)
            if tag == 4 {
                switch arr[1] {
                case .unsigned, .negative, .tagged(2, _), .tagged(3, _):
                    break
                default:
                    throw CBORError.invalidFormat("Tag 4 mantissa must be integer or bignum")
                }
            }

        case 21, 22, 23: // Base64url/base64/base16 conversion hints
            // These can contain any data type that will be converted
            break

        case 24: // Encoded CBOR data
            guard case .byteString = value else {
                throw CBORError.invalidFormat("Tag 24 requires byte string containing CBOR data")
            }

        case 25, 26: // String reference / Perl object
            // Implementation-specific, validation depends on context
            break

        case 30: // Rational number
            guard case .array(let arr) = value, arr.count == 2 else {
                throw CBORError.invalidFormat("Tag 30 requires array with 2 elements [numerator, denominator]")
            }
            // Both elements must be integers
            for (i, elem) in arr.enumerated() {
                switch elem {
                case .unsigned, .negative, .tagged(2, _), .tagged(3, _):
                    break
                default:
                    throw CBORError.invalidFormat("Tag 30 element \(i) must be integer or bignum")
                }
            }

        case 32: // URI
            guard case .textString = value else {
                throw CBORError.invalidFormat("Tag 32 requires text string URI")
            }

        case 33, 34: // Base64url/base64 encoded text
            guard case .textString = value else {
                throw CBORError.invalidFormat("Tag \(tag) requires text string")
            }

        case 35: // Regular expression
            guard case .textString = value else {
                throw CBORError.invalidFormat("Tag 35 requires text string regex")
            }

        case 36: // MIME message
            guard case .textString = value else {
                throw CBORError.invalidFormat("Tag 36 requires text string MIME message")
            }

        case 37: // UUID
            guard case .byteString(let data) = value, data.count == 16 else {
                throw CBORError.invalidFormat("Tag 37 requires 16-byte byte string for UUID")
            }

        case 38: // Language-tagged string
            guard case .array(let arr) = value,
                  arr.count == 2,
                  case .textString = arr[0], // Language tag
                  case .textString = arr[1]  // Text content
            else {
                throw CBORError.invalidFormat("Tag 38 requires [language-tag, text] array")
            }

        case 40, 41: // Multi-dimensional arrays
            guard case .array = value else {
                throw CBORError.invalidFormat("Tag \(tag) requires array")
            }

        case 42: // IPLD CID
            guard case .byteString = value else {
                throw CBORError.invalidFormat("Tag 42 requires byte string CID")
            }

        case 64...86: // Typed arrays
            guard case .byteString = value else {
                throw CBORError.invalidFormat("Tag \(tag) typed array requires byte string")
            }

        case 260: // Network address
            guard case .byteString(let data) = value,
                  data.count == 4 || data.count == 16 else { // IPv4 or IPv6
                throw CBORError.invalidFormat("Tag 260 requires 4 or 16 byte address")
            }

        case 261: // Network prefix
            guard case .byteString = value else {
                throw CBORError.invalidFormat("Tag 261 requires byte string prefix")
            }

        case 55799: // Self-describe CBOR
            // Can contain any CBOR value
            break

        default:
            // Unknown tags are allowed but not validated
            break
        }
    }

    private func readIndefiniteMap() throws -> CBORValue {
        var map = [CBORKey: CBORValue]()
        var seenKeys = Set<CBORKey>()
        while true {
            let key = try readValue()
            if case .break = key {
                break
            }
            let cborKey = CBORKey(key)

            // Check for duplicate keys
            if !allowDuplicateMapKeys && seenKeys.contains(cborKey) {
                throw CBORError.duplicateMapKey
            }
            seenKeys.insert(cborKey)

            let value = try readValue()
            map[cborKey] = value
        }
        return .map(map)
    }
}

final class _CBORDecoder: Decoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any]
    let options: CBORDecoder.Options
    let value: CBORValue

    init(data: [UInt8], options: CBORDecoder.Options) throws {
        self.options = options
        self.userInfo = options.userInfo
        let reader = CBORReader(bytes: data, allowDuplicateMapKeys: options.allowDuplicateMapKeys)
        self.value = try reader.readValue()
    }

    init(value: CBORValue, options: CBORDecoder.Options, codingPath: [CodingKey] = []) {
        self.value = value
        self.options = options
        self.userInfo = options.userInfo
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        guard case .map(let map) = value else {
            throw DecodingError.typeMismatch([String: Any].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected map, got \(value)"
            ))
        }
        let container = KeyedContainer<Key>(map: map, decoder: self, codingPath: codingPath)
        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .array(let array) = value else {
            throw DecodingError.typeMismatch([Any].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected array, got \(value)"
            ))
        }
        return UnkeyedContainer(array: array, decoder: self, codingPath: codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return SingleValueContainer(value: value, decoder: self, codingPath: codingPath)
    }
}

extension _CBORDecoder {
    final class SingleValueContainer: SingleValueDecodingContainer {
        var codingPath: [CodingKey]
        let value: CBORValue
        let decoder: _CBORDecoder

        init(value: CBORValue, decoder: _CBORDecoder, codingPath: [CodingKey]) {
            self.value = value
            self.decoder = decoder
            self.codingPath = codingPath
        }

        func decodeNil() -> Bool {
            if case .simple(.null) = value {
                return true
            }
            return false
        }

        func decode(_ type: Bool.Type) throws -> Bool {
            switch value {
            case .simple(.true):
                return true
            case .simple(.false):
                return false
            default:
                throw DecodingError.typeMismatch(type, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected Bool, got \(value)"
                ))
            }
        }

        func decode(_ type: String.Type) throws -> String {
            guard case .textString(let string) = value else {
                throw DecodingError.typeMismatch(type, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected String, got \(value)"
                ))
            }
            return string
        }

        func decode(_ type: Double.Type) throws -> Double {
            switch value {
            case .float64(let val):
                return val
            case .float32(let val):
                return Double(val)
            case .float16(let val):
                return Double(val)
            case .unsigned(let val):
                return Double(val)
            case .negative(let val):
                return Double(val)
            default:
                throw DecodingError.typeMismatch(type, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected Double, got \(value)"
                ))
            }
        }

        func decode(_ type: Float.Type) throws -> Float {
            switch value {
            case .float32(let val):
                return val
            case .float16(let val):
                return Float(val)
            case .float64(let val):
                return Float(val)
            case .unsigned(let val):
                return Float(val)
            case .negative(let val):
                return Float(val)
            default:
                throw DecodingError.typeMismatch(type, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected Float, got \(value)"
                ))
            }
        }

        func decode(_ type: Int.Type) throws -> Int {
            switch value {
            case .unsigned(let val):
                guard val <= Int.max else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(
                        codingPath: codingPath,
                        debugDescription: "Value \(val) out of range for Int"
                    ))
                }
                return Int(val)
            case .negative(let val):
                return Int(val)
            default:
                throw DecodingError.typeMismatch(type, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected Int, got \(value)"
                ))
            }
        }

        func decode(_ type: Int8.Type) throws -> Int8 {
            let intValue = try decode(Int.self)
            guard intValue >= Int8.min && intValue <= Int8.max else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Value \(intValue) out of range for Int8"
                ))
            }
            return Int8(intValue)
        }

        func decode(_ type: Int16.Type) throws -> Int16 {
            let intValue = try decode(Int.self)
            guard intValue >= Int16.min && intValue <= Int16.max else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Value \(intValue) out of range for Int16"
                ))
            }
            return Int16(intValue)
        }

        func decode(_ type: Int32.Type) throws -> Int32 {
            let intValue = try decode(Int.self)
            guard intValue >= Int32.min && intValue <= Int32.max else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Value \(intValue) out of range for Int32"
                ))
            }
            return Int32(intValue)
        }

        func decode(_ type: Int64.Type) throws -> Int64 {
            switch value {
            case .unsigned(let val):
                guard val <= Int64.max else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(
                        codingPath: codingPath,
                        debugDescription: "Value \(val) out of range for Int64"
                    ))
                }
                return Int64(val)
            case .negative(let val):
                return val
            default:
                throw DecodingError.typeMismatch(type, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected Int64, got \(value)"
                ))
            }
        }

        func decode(_ type: UInt.Type) throws -> UInt {
            guard case .unsigned(let val) = value else {
                throw DecodingError.typeMismatch(type, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected UInt, got \(value)"
                ))
            }
            return UInt(val)
        }

        func decode(_ type: UInt8.Type) throws -> UInt8 {
            guard case .unsigned(let val) = value else {
                throw DecodingError.typeMismatch(type, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected UInt8, got \(value)"
                ))
            }
            guard val <= UInt8.max else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Value \(val) out of range for UInt8"
                ))
            }
            return UInt8(val)
        }

        func decode(_ type: UInt16.Type) throws -> UInt16 {
            guard case .unsigned(let val) = value else {
                throw DecodingError.typeMismatch(type, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected UInt16, got \(value)"
                ))
            }
            guard val <= UInt16.max else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Value \(val) out of range for UInt16"
                ))
            }
            return UInt16(val)
        }

        func decode(_ type: UInt32.Type) throws -> UInt32 {
            guard case .unsigned(let val) = value else {
                throw DecodingError.typeMismatch(type, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected UInt32, got \(value)"
                ))
            }
            guard val <= UInt32.max else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Value \(val) out of range for UInt32"
                ))
            }
            return UInt32(val)
        }

        func decode(_ type: UInt64.Type) throws -> UInt64 {
            guard case .unsigned(let val) = value else {
                throw DecodingError.typeMismatch(type, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected UInt64, got \(value)"
                ))
            }
            return val
        }

        func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
            let decoder = _CBORDecoder(value: value, options: decoder.options, codingPath: codingPath)
            return try T(from: decoder)
        }
    }

    final class UnkeyedContainer: UnkeyedDecodingContainer {
        var codingPath: [CodingKey]
        var count: Int? { array.count }
        var isAtEnd: Bool { currentIndex >= array.count }
        var currentIndex: Int = 0

        private let array: [CBORValue]
        private let decoder: _CBORDecoder

        init(array: [CBORValue], decoder: _CBORDecoder, codingPath: [CodingKey]) {
            self.array = array
            self.decoder = decoder
            self.codingPath = codingPath
        }

        private func checkIndex() throws {
            guard !isAtEnd else {
                throw DecodingError.valueNotFound(Any.self, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Unkeyed container is at end"
                ))
            }
        }

        func decodeNil() throws -> Bool {
            try checkIndex()
            if case .simple(.null) = array[currentIndex] {
                currentIndex += 1
                return true
            }
            return false
        }

        func decode(_ type: Bool.Type) throws -> Bool {
            try checkIndex()
            let container = SingleValueContainer(value: array[currentIndex], decoder: decoder, codingPath: codingPath)
            let value = try container.decode(type)
            currentIndex += 1
            return value
        }

        func decode(_ type: String.Type) throws -> String {
            try checkIndex()
            let container = SingleValueContainer(value: array[currentIndex], decoder: decoder, codingPath: codingPath)
            let value = try container.decode(type)
            currentIndex += 1
            return value
        }

        func decode(_ type: Double.Type) throws -> Double {
            try checkIndex()
            let container = SingleValueContainer(value: array[currentIndex], decoder: decoder, codingPath: codingPath)
            let value = try container.decode(type)
            currentIndex += 1
            return value
        }

        func decode(_ type: Float.Type) throws -> Float {
            try checkIndex()
            let container = SingleValueContainer(value: array[currentIndex], decoder: decoder, codingPath: codingPath)
            let value = try container.decode(type)
            currentIndex += 1
            return value
        }

        func decode(_ type: Int.Type) throws -> Int {
            try checkIndex()
            let container = SingleValueContainer(value: array[currentIndex], decoder: decoder, codingPath: codingPath)
            let value = try container.decode(type)
            currentIndex += 1
            return value
        }

        func decode(_ type: Int8.Type) throws -> Int8 {
            try checkIndex()
            let container = SingleValueContainer(value: array[currentIndex], decoder: decoder, codingPath: codingPath)
            let value = try container.decode(type)
            currentIndex += 1
            return value
        }

        func decode(_ type: Int16.Type) throws -> Int16 {
            try checkIndex()
            let container = SingleValueContainer(value: array[currentIndex], decoder: decoder, codingPath: codingPath)
            let value = try container.decode(type)
            currentIndex += 1
            return value
        }

        func decode(_ type: Int32.Type) throws -> Int32 {
            try checkIndex()
            let container = SingleValueContainer(value: array[currentIndex], decoder: decoder, codingPath: codingPath)
            let value = try container.decode(type)
            currentIndex += 1
            return value
        }

        func decode(_ type: Int64.Type) throws -> Int64 {
            try checkIndex()
            let container = SingleValueContainer(value: array[currentIndex], decoder: decoder, codingPath: codingPath)
            let value = try container.decode(type)
            currentIndex += 1
            return value
        }

        func decode(_ type: UInt.Type) throws -> UInt {
            try checkIndex()
            let container = SingleValueContainer(value: array[currentIndex], decoder: decoder, codingPath: codingPath)
            let value = try container.decode(type)
            currentIndex += 1
            return value
        }

        func decode(_ type: UInt8.Type) throws -> UInt8 {
            try checkIndex()
            let container = SingleValueContainer(value: array[currentIndex], decoder: decoder, codingPath: codingPath)
            let value = try container.decode(type)
            currentIndex += 1
            return value
        }

        func decode(_ type: UInt16.Type) throws -> UInt16 {
            try checkIndex()
            let container = SingleValueContainer(value: array[currentIndex], decoder: decoder, codingPath: codingPath)
            let value = try container.decode(type)
            currentIndex += 1
            return value
        }

        func decode(_ type: UInt32.Type) throws -> UInt32 {
            try checkIndex()
            let container = SingleValueContainer(value: array[currentIndex], decoder: decoder, codingPath: codingPath)
            let value = try container.decode(type)
            currentIndex += 1
            return value
        }

        func decode(_ type: UInt64.Type) throws -> UInt64 {
            try checkIndex()
            let container = SingleValueContainer(value: array[currentIndex], decoder: decoder, codingPath: codingPath)
            let value = try container.decode(type)
            currentIndex += 1
            return value
        }

        func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
            try checkIndex()
            let decoder = _CBORDecoder(value: array[currentIndex], options: decoder.options, codingPath: codingPath)
            let value = try T(from: decoder)
            currentIndex += 1
            return value
        }

        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
            try checkIndex()
            let decoder = _CBORDecoder(value: array[currentIndex], options: decoder.options, codingPath: codingPath)
            currentIndex += 1
            return try decoder.container(keyedBy: type)
        }

        func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            try checkIndex()
            let decoder = _CBORDecoder(value: array[currentIndex], options: decoder.options, codingPath: codingPath)
            currentIndex += 1
            return try decoder.unkeyedContainer()
        }

        func superDecoder() throws -> Decoder {
            try checkIndex()
            let decoder = _CBORDecoder(value: array[currentIndex], options: decoder.options, codingPath: codingPath)
            currentIndex += 1
            return decoder
        }
    }

    final class KeyedContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
        typealias Key = K

        var codingPath: [CodingKey]
        var allKeys: [K] {
            map.keys.compactMap { key in
                guard case .textString(let str) = key.value else { return nil }
                return K(stringValue: str)
            }
        }

        private let map: [CBORKey: CBORValue]
        private let decoder: _CBORDecoder

        init(map: [CBORKey: CBORValue], decoder: _CBORDecoder, codingPath: [CodingKey]) {
            self.map = map
            self.decoder = decoder
            self.codingPath = codingPath
        }

        func contains(_ key: K) -> Bool {
            return map[CBORKey(.textString(key.stringValue))] != nil
        }

        private func getValue(for key: K) throws -> CBORValue {
            guard let value = map[CBORKey(.textString(key.stringValue))] else {
                throw DecodingError.keyNotFound(key, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Key '\(key.stringValue)' not found"
                ))
            }
            return value
        }

        func decodeNil(forKey key: K) throws -> Bool {
            let value = try getValue(for: key)
            if case .simple(.null) = value {
                return true
            }
            return false
        }

        func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
            let value = try getValue(for: key)
            let container = SingleValueContainer(value: value, decoder: decoder, codingPath: codingPath + [key])
            return try container.decode(type)
        }

        func decode(_ type: String.Type, forKey key: K) throws -> String {
            let value = try getValue(for: key)
            let container = SingleValueContainer(value: value, decoder: decoder, codingPath: codingPath + [key])
            return try container.decode(type)
        }

        func decode(_ type: Double.Type, forKey key: K) throws -> Double {
            let value = try getValue(for: key)
            let container = SingleValueContainer(value: value, decoder: decoder, codingPath: codingPath + [key])
            return try container.decode(type)
        }

        func decode(_ type: Float.Type, forKey key: K) throws -> Float {
            let value = try getValue(for: key)
            let container = SingleValueContainer(value: value, decoder: decoder, codingPath: codingPath + [key])
            return try container.decode(type)
        }

        func decode(_ type: Int.Type, forKey key: K) throws -> Int {
            let value = try getValue(for: key)
            let container = SingleValueContainer(value: value, decoder: decoder, codingPath: codingPath + [key])
            return try container.decode(type)
        }

        func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 {
            let value = try getValue(for: key)
            let container = SingleValueContainer(value: value, decoder: decoder, codingPath: codingPath + [key])
            return try container.decode(type)
        }

        func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 {
            let value = try getValue(for: key)
            let container = SingleValueContainer(value: value, decoder: decoder, codingPath: codingPath + [key])
            return try container.decode(type)
        }

        func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 {
            let value = try getValue(for: key)
            let container = SingleValueContainer(value: value, decoder: decoder, codingPath: codingPath + [key])
            return try container.decode(type)
        }

        func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 {
            let value = try getValue(for: key)
            let container = SingleValueContainer(value: value, decoder: decoder, codingPath: codingPath + [key])
            return try container.decode(type)
        }

        func decode(_ type: UInt.Type, forKey key: K) throws -> UInt {
            let value = try getValue(for: key)
            let container = SingleValueContainer(value: value, decoder: decoder, codingPath: codingPath + [key])
            return try container.decode(type)
        }

        func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 {
            let value = try getValue(for: key)
            let container = SingleValueContainer(value: value, decoder: decoder, codingPath: codingPath + [key])
            return try container.decode(type)
        }

        func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 {
            let value = try getValue(for: key)
            let container = SingleValueContainer(value: value, decoder: decoder, codingPath: codingPath + [key])
            return try container.decode(type)
        }

        func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 {
            let value = try getValue(for: key)
            let container = SingleValueContainer(value: value, decoder: decoder, codingPath: codingPath + [key])
            return try container.decode(type)
        }

        func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 {
            let value = try getValue(for: key)
            let container = SingleValueContainer(value: value, decoder: decoder, codingPath: codingPath + [key])
            return try container.decode(type)
        }

        func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T: Decodable {
            let value = try getValue(for: key)
            let decoder = _CBORDecoder(value: value, options: decoder.options, codingPath: codingPath + [key])
            return try T(from: decoder)
        }

        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
            let value = try getValue(for: key)
            let decoder = _CBORDecoder(value: value, options: decoder.options, codingPath: codingPath + [key])
            return try decoder.container(keyedBy: type)
        }

        func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
            let value = try getValue(for: key)
            let decoder = _CBORDecoder(value: value, options: decoder.options, codingPath: codingPath + [key])
            return try decoder.unkeyedContainer()
        }

        func superDecoder() throws -> Decoder {
            return decoder
        }

        func superDecoder(forKey key: K) throws -> Decoder {
            let value = try getValue(for: key)
            return _CBORDecoder(value: value, options: decoder.options, codingPath: codingPath + [key])
        }
    }
}