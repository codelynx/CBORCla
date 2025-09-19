# CBORCla

A Swift implementation of CBOR (Concise Binary Object Representation) as specified in RFC 8949.

## Features

- Full RFC 8949 compliance
- Codable protocol support for seamless encoding/decoding
- Support for all CBOR major types (0-7)
- Indefinite-length arrays, maps, and strings
- CBOR tags support
- Canonical CBOR encoding
- Comprehensive test coverage
- High performance

## Installation

### Swift Package Manager

Add CBORCla to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/codelynx/CBORCla.git", from: "1.0.0")
]
```

## Usage

### Basic Encoding

```swift
import CBORCla

let encoder = CBOREncoder()

// Encode primitive types
let intData = try encoder.encode(42)
let stringData = try encoder.encode("Hello, CBOR!")
let arrayData = try encoder.encode([1, 2, 3])

// Encode Codable structs
struct Person: Codable {
    let name: String
    let age: Int
}

let person = Person(name: "Alice", age: 30)
let personData = try encoder.encode(person)
```

### Basic Decoding

```swift
import CBORCla

let decoder = CBORDecoder()

// Decode primitive types
let intValue = try decoder.decode(Int.self, from: intData)
let stringValue = try decoder.decode(String.self, from: stringData)
let arrayValue = try decoder.decode([Int].self, from: arrayData)

// Decode Codable structs
let decodedPerson = try decoder.decode(Person.self, from: personData)
```

### Working with CBORValue

```swift
// Create CBOR values directly
let value = CBORValue.map([
    CBORKey(.textString("name")): .textString("Bob"),
    CBORKey(.textString("age")): .unsigned(25),
    CBORKey(.textString("active")): .simple(.true)
])

// Decode to CBORValue for dynamic content
let decodedValue = try decoder.decodeValue(from: someData)

switch decodedValue {
case .unsigned(let val):
    print("Unsigned integer: \(val)")
case .textString(let str):
    print("String: \(str)")
case .array(let arr):
    print("Array with \(arr.count) elements")
case .map(let dict):
    print("Map with \(dict.count) key-value pairs")
default:
    print("Other CBOR type")
}
```

### Advanced Options

```swift
let encoder = CBOREncoder()

// Sort map keys for deterministic encoding
encoder.options.sortKeys = true

// Use canonical encoding (RFC 8949 Section 4.2)
encoder.options.useCanonicalEncoding = true

// Date encoding strategies
encoder.options.dateEncodingStrategy = .epochTime      // Default
encoder.options.dateEncodingStrategy = .tagged         // CBOR tag 1
encoder.options.dateEncodingStrategy = .iso8601String  // Text string

// Data encoding strategies
encoder.options.dataEncodingStrategy = .byteString     // Default
encoder.options.dataEncodingStrategy = .base64String   // Text string

let decoder = CBORDecoder()

// Allow duplicate map keys (not recommended)
decoder.options.allowDuplicateMapKeys = true

// Set maximum nesting depth
decoder.options.maxDepth = 100
```

### Indefinite-Length Items

CBORCla automatically handles indefinite-length items during decoding:

```swift
// Indefinite-length array: [_ 1, 2, 3]
let indefiniteArray = Data([0x9f, 0x01, 0x02, 0x03, 0xff])
let array = try decoder.decode([Int].self, from: indefiniteArray)

// Indefinite-length map: {_ "a": 1, "b": 2}
let indefiniteMap = Data([0xbf, 0x61, 0x61, 0x01, 0x61, 0x62, 0x02, 0xff])
let map = try decoder.decode([String: Int].self, from: indefiniteMap)

// Indefinite-length byte string
let indefiniteBytes = Data([0x5f, 0x42, 0x01, 0x02, 0x43, 0x03, 0x04, 0x05, 0xff])
let value = try decoder.decodeValue(from: indefiniteBytes)
```

### CBOR Tags

```swift
// Decode tagged values
let taggedData = Data([0xc1, 0xfb, 0x41, 0xd4, 0x52, 0xd9, 0xec, 0x20, 0x00, 0x00])
let value = try decoder.decodeValue(from: taggedData)

if case .tagged(let tag, let boxedValue) = value {
    print("Tag: \(tag)")
    print("Value: \(boxedValue.value)")
}

// Common tags
// Tag 0: Standard date/time string
// Tag 1: Epoch-based date/time
// Tag 2: Positive bignum
// Tag 3: Negative bignum
// Tag 24: Encoded CBOR data item
// Tag 32: URI
// Tag 55799: Self-described CBOR
```

## CBOR Major Types

CBORCla supports all CBOR major types as defined in RFC 8949:

- **Type 0**: Unsigned integer (0..2^64-1)
- **Type 1**: Negative integer (-2^64..-1)
- **Type 2**: Byte string
- **Type 3**: Text string (UTF-8)
- **Type 4**: Array
- **Type 5**: Map
- **Type 6**: Tagged value
- **Type 7**: Primitives (false, true, null, undefined, floats)

## Requirements

- iOS 14.0+ / macOS 11.0+ / tvOS 14.0+ / watchOS 7.0+
- Swift 5.5+
- Xcode 12.0+

## Testing

Run tests using Swift Package Manager:

```bash
swift test
```

## Performance

CBORCla is optimized for performance with:
- Efficient binary serialization
- Minimal allocations
- Direct byte manipulation
- Streaming support for large data

## Contributing

Contributions are welcome! Please feel free to submit pull requests.

## License

CBORCla is available under the MIT license. See the LICENSE file for more info.

## References

- [RFC 8949: Concise Binary Object Representation (CBOR)](https://datatracker.ietf.org/doc/html/rfc8949)
- [CBOR.io](https://cbor.io/)
- [IANA CBOR Registry](https://www.iana.org/assignments/cbor-tags/cbor-tags.xhtml)