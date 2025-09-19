import Foundation

// Helper for coding keys
struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

public class CBOREncoder {
    public struct Options {
        public var dateEncodingStrategy: DateEncodingStrategy = .epochTime
        public var dataEncodingStrategy: DataEncodingStrategy = .byteString
        public var nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy = .convertToString
        public var keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys
        public var userInfo: [CodingUserInfoKey: Any] = [:]
        public var sortKeys: Bool = false
        public var useCanonicalEncoding: Bool = false

        public init() {}
    }

    public enum DateEncodingStrategy {
        case epochTime
        case tagged
        case iso8601String
        case custom((Date, Encoder) throws -> Void)
    }

    public enum DataEncodingStrategy {
        case byteString
        case base64String
        case custom((Data, Encoder) throws -> Void)
    }

    public enum NonConformingFloatEncodingStrategy {
        case convertToString
        case `throw`
    }

    public enum KeyEncodingStrategy {
        case useDefaultKeys
        case convertToSnakeCase
        case custom(([CodingKey]) -> CodingKey)
    }

    public var options = Options()

    public init() {}

    public func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = _CBOREncoder(options: options)

        // Handle special types at the top level
        if let data = value as? Data {
            switch options.dataEncodingStrategy {
            case .byteString:
                encoder.encodeData(data)
            case .base64String:
                encoder.encodeString(data.base64EncodedString())
            case .custom(let closure):
                try closure(data, encoder)
            }
        } else if let date = value as? Date {
            try encoder.encodeDate(date)
        } else {
            try value.encode(to: encoder)
        }

        return encoder.data
    }

    public func encodeToBytes<T: Encodable>(_ value: T) throws -> [UInt8] {
        let data = try encode(value)
        return Array(data)
    }
}

final class _CBOREncoder: Encoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any]
    let options: CBOREncoder.Options
    var data = Data()

    init(options: CBOREncoder.Options) {
        self.options = options
        self.userInfo = options.userInfo
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        let container = KeyedContainer<Key>(encoder: self, codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return UnkeyedContainer(encoder: self, codingPath: codingPath)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return SingleValueContainer(encoder: self, codingPath: codingPath)
    }

    func writeMajorType(_ majorType: CBORMajorType, value: UInt64) {
        let major = majorType.rawValue << 5

        // Canonical encoding: use shortest possible representation
        if options.useCanonicalEncoding {
            if value < 24 {
                data.append(major | UInt8(value))
            } else if value <= UInt8.max {
                data.append(major | 24)
                data.append(UInt8(value))
            } else if value <= UInt16.max {
                data.append(major | 25)
                var value = UInt16(value).bigEndian
                data.append(contentsOf: withUnsafeBytes(of: &value, Array.init))
            } else if value <= UInt32.max {
                data.append(major | 26)
                var value = UInt32(value).bigEndian
                data.append(contentsOf: withUnsafeBytes(of: &value, Array.init))
            } else {
                data.append(major | 27)
                var value = value.bigEndian
                data.append(contentsOf: withUnsafeBytes(of: &value, Array.init))
            }
        } else {
            // Non-canonical: current behavior
            if value < 24 {
                data.append(major | UInt8(value))
            } else if value <= UInt8.max {
                data.append(major | 24)
                data.append(UInt8(value))
            } else if value <= UInt16.max {
                data.append(major | 25)
                var value = UInt16(value).bigEndian
                data.append(contentsOf: withUnsafeBytes(of: &value, Array.init))
            } else if value <= UInt32.max {
                data.append(major | 26)
                var value = UInt32(value).bigEndian
                data.append(contentsOf: withUnsafeBytes(of: &value, Array.init))
            } else {
                data.append(major | 27)
                var value = value.bigEndian
                data.append(contentsOf: withUnsafeBytes(of: &value, Array.init))
            }
        }
    }

    func encodeNil() {
        data.append(0xf6)
    }

    func encodeBool(_ value: Bool) {
        data.append(value ? 0xf5 : 0xf4)
    }

    func encodeString(_ value: String) {
        let utf8 = value.utf8
        writeMajorType(.textString, value: UInt64(utf8.count))
        data.append(contentsOf: utf8)
    }

    func encodeData(_ value: Data) {
        writeMajorType(.byteString, value: UInt64(value.count))
        data.append(value)
    }

    func encodeInt(_ value: Int64) {
        if value >= 0 {
            writeMajorType(.unsigned, value: UInt64(value))
        } else {
            writeMajorType(.negative, value: UInt64(-value - 1))
        }
    }

    func encodeUInt(_ value: UInt64) {
        writeMajorType(.unsigned, value: value)
    }

    func encodeFloat(_ value: Float) {
        if options.useCanonicalEncoding {
            // Canonical: encode NaN as 0xf97e00
            if value.isNaN {
                data.append(contentsOf: [0xf9, 0x7e, 0x00])
            } else if value.isInfinite {
                // Canonical: use shortest form for infinity
                if value > 0 {
                    data.append(contentsOf: [0xf9, 0x7c, 0x00])  // +Infinity
                } else {
                    data.append(contentsOf: [0xf9, 0xfc, 0x00])  // -Infinity
                }
            } else {
                // Check if we can represent as Float16 without loss
                let half = Float16(value)
                if Float(half) == value {
                    encodeFloat16(half)
                } else {
                    // Use Float32
                    data.append(0xfa)
                    var value = value.bitPattern.bigEndian
                    data.append(contentsOf: withUnsafeBytes(of: &value, Array.init))
                }
            }
        } else {
            data.append(0xfa)
            var value = value.bitPattern.bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &value, Array.init))
        }
    }

    func encodeDouble(_ value: Double) {
        if options.useCanonicalEncoding {
            // Canonical: encode NaN as 0xf97e00
            if value.isNaN {
                data.append(contentsOf: [0xf9, 0x7e, 0x00])
            } else if value.isInfinite {
                // Canonical: use shortest form for infinity
                if value > 0 {
                    data.append(contentsOf: [0xf9, 0x7c, 0x00])  // +Infinity
                } else {
                    data.append(contentsOf: [0xf9, 0xfc, 0x00])  // -Infinity
                }
            } else {
                // Try Float16 first, then Float32, then Float64
                let floatValue = Float(value)
                if Double(floatValue) == value {
                    // Can represent as Float without loss
                    let half = Float16(floatValue)
                    if Double(Float(half)) == value {
                        encodeFloat16(half)
                    } else if Double(floatValue) == value {
                        data.append(0xfa)
                        var bits = floatValue.bitPattern.bigEndian
                        data.append(contentsOf: withUnsafeBytes(of: &bits, Array.init))
                    } else {
                        // Use Float64
                        data.append(0xfb)
                        var bits = value.bitPattern.bigEndian
                        data.append(contentsOf: withUnsafeBytes(of: &bits, Array.init))
                    }
                } else {
                    // Must use Float64
                    data.append(0xfb)
                    var bits = value.bitPattern.bigEndian
                    data.append(contentsOf: withUnsafeBytes(of: &bits, Array.init))
                }
            }
        } else {
            data.append(0xfb)
            var value = value.bitPattern.bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &value, Array.init))
        }
    }

    func encodeFloat16(_ value: Float16) {
        data.append(0xf9)
        var value = value.bitPattern.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &value, Array.init))
    }

    func encodeDate(_ date: Date) throws {
        switch options.dateEncodingStrategy {
        case .epochTime:
            encodeDouble(date.timeIntervalSince1970)
        case .tagged:
            writeMajorType(.tag, value: 1)
            encodeDouble(date.timeIntervalSince1970)
        case .iso8601String:
            let formatter = ISO8601DateFormatter()
            encodeString(formatter.string(from: date))
        case .custom(let closure):
            try closure(date, self)
        }
    }
}

extension _CBOREncoder {
    final class SingleValueContainer: SingleValueEncodingContainer {
        var codingPath: [CodingKey]
        let encoder: _CBOREncoder

        init(encoder: _CBOREncoder, codingPath: [CodingKey]) {
            self.encoder = encoder
            self.codingPath = codingPath
        }

        func encodeNil() throws {
            encoder.encodeNil()
        }

        func encode(_ value: Bool) throws {
            encoder.encodeBool(value)
        }

        func encode(_ value: String) throws {
            encoder.encodeString(value)
        }

        func encode(_ value: Double) throws {
            encoder.encodeDouble(value)
        }

        func encode(_ value: Float) throws {
            encoder.encodeFloat(value)
        }

        func encode(_ value: Int) throws {
            encoder.encodeInt(Int64(value))
        }

        func encode(_ value: Int8) throws {
            encoder.encodeInt(Int64(value))
        }

        func encode(_ value: Int16) throws {
            encoder.encodeInt(Int64(value))
        }

        func encode(_ value: Int32) throws {
            encoder.encodeInt(Int64(value))
        }

        func encode(_ value: Int64) throws {
            encoder.encodeInt(value)
        }

        func encode(_ value: UInt) throws {
            encoder.encodeUInt(UInt64(value))
        }

        func encode(_ value: UInt8) throws {
            encoder.encodeUInt(UInt64(value))
        }

        func encode(_ value: UInt16) throws {
            encoder.encodeUInt(UInt64(value))
        }

        func encode(_ value: UInt32) throws {
            encoder.encodeUInt(UInt64(value))
        }

        func encode(_ value: UInt64) throws {
            encoder.encodeUInt(value)
        }

        func encode<T>(_ value: T) throws where T: Encodable {
            // Handle Data specially according to dataEncodingStrategy
            if let data = value as? Data {
                switch encoder.options.dataEncodingStrategy {
                case .byteString:
                    encoder.encodeData(data)
                case .base64String:
                    encoder.encodeString(data.base64EncodedString())
                case .custom(let closure):
                    try closure(data, encoder)
                }
            } else if let date = value as? Date {
                try encoder.encodeDate(date)
            } else {
                try value.encode(to: encoder)
            }
        }
    }

    final class UnkeyedContainer: UnkeyedEncodingContainer {
        var codingPath: [CodingKey]
        var count: Int = 0
        let encoder: _CBOREncoder
        private var elements = [Data]()

        init(encoder: _CBOREncoder, codingPath: [CodingKey]) {
            self.encoder = encoder
            self.codingPath = codingPath
        }

        deinit {
            encoder.writeMajorType(.array, value: UInt64(elements.count))
            for element in elements {
                encoder.data.append(element)
            }
        }

        func encodeNil() throws {
            let container = _CBOREncoder(options: encoder.options)
            container.encodeNil()
            elements.append(container.data)
            count += 1
        }

        func encode(_ value: Bool) throws {
            let container = _CBOREncoder(options: encoder.options)
            container.encodeBool(value)
            elements.append(container.data)
            count += 1
        }

        func encode(_ value: String) throws {
            let container = _CBOREncoder(options: encoder.options)
            container.encodeString(value)
            elements.append(container.data)
            count += 1
        }

        func encode(_ value: Double) throws {
            let container = _CBOREncoder(options: encoder.options)
            container.encodeDouble(value)
            elements.append(container.data)
            count += 1
        }

        func encode(_ value: Float) throws {
            let container = _CBOREncoder(options: encoder.options)
            container.encodeFloat(value)
            elements.append(container.data)
            count += 1
        }

        func encode(_ value: Int) throws {
            let container = _CBOREncoder(options: encoder.options)
            container.encodeInt(Int64(value))
            elements.append(container.data)
            count += 1
        }

        func encode(_ value: Int8) throws {
            let container = _CBOREncoder(options: encoder.options)
            container.encodeInt(Int64(value))
            elements.append(container.data)
            count += 1
        }

        func encode(_ value: Int16) throws {
            let container = _CBOREncoder(options: encoder.options)
            container.encodeInt(Int64(value))
            elements.append(container.data)
            count += 1
        }

        func encode(_ value: Int32) throws {
            let container = _CBOREncoder(options: encoder.options)
            container.encodeInt(Int64(value))
            elements.append(container.data)
            count += 1
        }

        func encode(_ value: Int64) throws {
            let container = _CBOREncoder(options: encoder.options)
            container.encodeInt(value)
            elements.append(container.data)
            count += 1
        }

        func encode(_ value: UInt) throws {
            let container = _CBOREncoder(options: encoder.options)
            container.encodeUInt(UInt64(value))
            elements.append(container.data)
            count += 1
        }

        func encode(_ value: UInt8) throws {
            let container = _CBOREncoder(options: encoder.options)
            container.encodeUInt(UInt64(value))
            elements.append(container.data)
            count += 1
        }

        func encode(_ value: UInt16) throws {
            let container = _CBOREncoder(options: encoder.options)
            container.encodeUInt(UInt64(value))
            elements.append(container.data)
            count += 1
        }

        func encode(_ value: UInt32) throws {
            let container = _CBOREncoder(options: encoder.options)
            container.encodeUInt(UInt64(value))
            elements.append(container.data)
            count += 1
        }

        func encode(_ value: UInt64) throws {
            let container = _CBOREncoder(options: encoder.options)
            container.encodeUInt(value)
            elements.append(container.data)
            count += 1
        }

        func encode<T>(_ value: T) throws where T: Encodable {
            let container = _CBOREncoder(options: encoder.options)

            // Handle special types
            if let data = value as? Data {
                switch encoder.options.dataEncodingStrategy {
                case .byteString:
                    container.encodeData(data)
                case .base64String:
                    container.encodeString(data.base64EncodedString())
                case .custom(let closure):
                    try closure(data, container)
                }
            } else if let date = value as? Date {
                try container.encodeDate(date)
            } else {
                try value.encode(to: container)
            }

            elements.append(container.data)
            count += 1
        }

        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
            let nestedEncoder = _CBOREncoder(options: encoder.options)
            let container = KeyedContainer<NestedKey>(encoder: nestedEncoder, codingPath: codingPath)
            elements.append(nestedEncoder.data)
            count += 1
            return KeyedEncodingContainer(container)
        }

        func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            let nestedEncoder = _CBOREncoder(options: encoder.options)
            let container = UnkeyedContainer(encoder: nestedEncoder, codingPath: codingPath)
            elements.append(nestedEncoder.data)
            count += 1
            return container
        }

        func superEncoder() -> Encoder {
            let nestedEncoder = _CBOREncoder(options: encoder.options)
            elements.append(nestedEncoder.data)
            count += 1
            return nestedEncoder
        }
    }

    final class KeyedContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
        typealias Key = K

        var codingPath: [CodingKey]
        let encoder: _CBOREncoder
        private var elements = [(Data, Data)]()

        init(encoder: _CBOREncoder, codingPath: [CodingKey]) {
            self.encoder = encoder
            self.codingPath = codingPath
        }

        deinit {
            if encoder.options.sortKeys || encoder.options.useCanonicalEncoding {
                // Canonical encoding: sort by encoded key length first, then lexicographically
                elements.sort { lhs, rhs in
                    if encoder.options.useCanonicalEncoding {
                        // Canonical: length first, then lexicographic
                        if lhs.0.count != rhs.0.count {
                            return lhs.0.count < rhs.0.count
                        }
                    }
                    return lhs.0.lexicographicallyPrecedes(rhs.0)
                }
            }

            encoder.writeMajorType(.map, value: UInt64(elements.count))
            for (key, value) in elements {
                encoder.data.append(key)
                encoder.data.append(value)
            }
        }

        private func encodeKey(_ key: K) -> Data {
            let keyEncoder = _CBOREncoder(options: encoder.options)
            keyEncoder.encodeString(key.stringValue)
            return keyEncoder.data
        }

        func encodeNil(forKey key: K) throws {
            let keyData = encodeKey(key)
            let valueEncoder = _CBOREncoder(options: encoder.options)
            valueEncoder.encodeNil()
            elements.append((keyData, valueEncoder.data))
        }

        func encode(_ value: Bool, forKey key: K) throws {
            let keyData = encodeKey(key)
            let valueEncoder = _CBOREncoder(options: encoder.options)
            valueEncoder.encodeBool(value)
            elements.append((keyData, valueEncoder.data))
        }

        func encode(_ value: String, forKey key: K) throws {
            let keyData = encodeKey(key)
            let valueEncoder = _CBOREncoder(options: encoder.options)
            valueEncoder.encodeString(value)
            elements.append((keyData, valueEncoder.data))
        }

        func encode(_ value: Double, forKey key: K) throws {
            let keyData = encodeKey(key)
            let valueEncoder = _CBOREncoder(options: encoder.options)
            valueEncoder.encodeDouble(value)
            elements.append((keyData, valueEncoder.data))
        }

        func encode(_ value: Float, forKey key: K) throws {
            let keyData = encodeKey(key)
            let valueEncoder = _CBOREncoder(options: encoder.options)
            valueEncoder.encodeFloat(value)
            elements.append((keyData, valueEncoder.data))
        }

        func encode(_ value: Int, forKey key: K) throws {
            let keyData = encodeKey(key)
            let valueEncoder = _CBOREncoder(options: encoder.options)
            valueEncoder.encodeInt(Int64(value))
            elements.append((keyData, valueEncoder.data))
        }

        func encode(_ value: Int8, forKey key: K) throws {
            let keyData = encodeKey(key)
            let valueEncoder = _CBOREncoder(options: encoder.options)
            valueEncoder.encodeInt(Int64(value))
            elements.append((keyData, valueEncoder.data))
        }

        func encode(_ value: Int16, forKey key: K) throws {
            let keyData = encodeKey(key)
            let valueEncoder = _CBOREncoder(options: encoder.options)
            valueEncoder.encodeInt(Int64(value))
            elements.append((keyData, valueEncoder.data))
        }

        func encode(_ value: Int32, forKey key: K) throws {
            let keyData = encodeKey(key)
            let valueEncoder = _CBOREncoder(options: encoder.options)
            valueEncoder.encodeInt(Int64(value))
            elements.append((keyData, valueEncoder.data))
        }

        func encode(_ value: Int64, forKey key: K) throws {
            let keyData = encodeKey(key)
            let valueEncoder = _CBOREncoder(options: encoder.options)
            valueEncoder.encodeInt(value)
            elements.append((keyData, valueEncoder.data))
        }

        func encode(_ value: UInt, forKey key: K) throws {
            let keyData = encodeKey(key)
            let valueEncoder = _CBOREncoder(options: encoder.options)
            valueEncoder.encodeUInt(UInt64(value))
            elements.append((keyData, valueEncoder.data))
        }

        func encode(_ value: UInt8, forKey key: K) throws {
            let keyData = encodeKey(key)
            let valueEncoder = _CBOREncoder(options: encoder.options)
            valueEncoder.encodeUInt(UInt64(value))
            elements.append((keyData, valueEncoder.data))
        }

        func encode(_ value: UInt16, forKey key: K) throws {
            let keyData = encodeKey(key)
            let valueEncoder = _CBOREncoder(options: encoder.options)
            valueEncoder.encodeUInt(UInt64(value))
            elements.append((keyData, valueEncoder.data))
        }

        func encode(_ value: UInt32, forKey key: K) throws {
            let keyData = encodeKey(key)
            let valueEncoder = _CBOREncoder(options: encoder.options)
            valueEncoder.encodeUInt(UInt64(value))
            elements.append((keyData, valueEncoder.data))
        }

        func encode(_ value: UInt64, forKey key: K) throws {
            let keyData = encodeKey(key)
            let valueEncoder = _CBOREncoder(options: encoder.options)
            valueEncoder.encodeUInt(value)
            elements.append((keyData, valueEncoder.data))
        }

        func encode<T>(_ value: T, forKey key: K) throws where T: Encodable {
            let keyData = encodeKey(key)
            let valueEncoder = _CBOREncoder(options: encoder.options)

            // Handle special types
            if let data = value as? Data {
                switch encoder.options.dataEncodingStrategy {
                case .byteString:
                    valueEncoder.encodeData(data)
                case .base64String:
                    valueEncoder.encodeString(data.base64EncodedString())
                case .custom(let closure):
                    try closure(data, valueEncoder)
                }
            } else if let date = value as? Date {
                try valueEncoder.encodeDate(date)
            } else {
                try value.encode(to: valueEncoder)
            }

            elements.append((keyData, valueEncoder.data))
        }

        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
            let keyData = encodeKey(key)
            let nestedEncoder = _CBOREncoder(options: encoder.options)
            let container = KeyedContainer<NestedKey>(encoder: nestedEncoder, codingPath: codingPath + [key])
            elements.append((keyData, nestedEncoder.data))
            return KeyedEncodingContainer(container)
        }

        func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
            let keyData = encodeKey(key)
            let nestedEncoder = _CBOREncoder(options: encoder.options)
            let container = UnkeyedContainer(encoder: nestedEncoder, codingPath: codingPath + [key])
            elements.append((keyData, nestedEncoder.data))
            return container
        }

        func superEncoder() -> Encoder {
            // Create a synthetic key for super encoder
            let superKey = "super"
            let keyEncoder = _CBOREncoder(options: encoder.options)
            keyEncoder.encodeString(superKey)
            let keyData = keyEncoder.data

            let nestedEncoder = _CBOREncoder(options: encoder.options)
            elements.append((keyData, nestedEncoder.data))
            return nestedEncoder
        }

        func superEncoder(forKey key: K) -> Encoder {
            let keyData = encodeKey(key)
            let nestedEncoder = _CBOREncoder(options: encoder.options)
            elements.append((keyData, nestedEncoder.data))
            return nestedEncoder
        }
    }
}