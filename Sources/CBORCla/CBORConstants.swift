import Foundation

public enum CBORMajorType: UInt8 {
    case unsigned = 0
    case negative = 1
    case byteString = 2
    case textString = 3
    case array = 4
    case map = 5
    case tag = 6
    case primitive = 7
}

public enum CBORAdditionalInfo: UInt8 {
    case direct = 0
    case oneByte = 24
    case twoBytes = 25
    case fourBytes = 26
    case eightBytes = 27
    case indefinite = 31
}

public enum CBORTag: UInt64 {
    // RFC 8949 Core Tags
    case standardDateTime = 0       // Text string in RFC 3339 format
    case epochDateTime = 1          // Numeric epoch-based date/time
    case positiveBignum = 2         // Byte string as unsigned bignum
    case negativeBignum = 3         // Byte string as negative bignum
    case decimalFraction = 4        // Array: [exponent, mantissa]
    case bigfloat = 5               // Array: [exponent, mantissa]

    // RFC 8949 Optional Tags
    case base64UrlConversion = 21   // Expected conversion to base64url
    case base64Conversion = 22      // Expected conversion to base64
    case base16Conversion = 23      // Expected conversion to base16
    case encodedCBORData = 24       // Embedded CBOR data item

    // String References (RFC 8949)
    case stringReference = 25       // Reference to string defined elsewhere
    case perlSerializedObject = 26  // Serialized Perl object

    // Network Addresses (RFC 9164)
    case networkAddress = 260       // Network address (IPv4 or IPv6)
    case networkPrefix = 261        // Network prefix (IPv4 or IPv6)

    // RFC 8746 Tags
    case uri = 32                   // URI text string
    case base64Url = 33             // Base64url-encoded text string
    case base64 = 34                // Base64-encoded text string
    case regex = 35                 // Regular expression text string
    case mimeMessage = 36           // MIME message text string

    // UUID (RFC 8949)
    case uuid = 37                  // Binary UUID

    // Language Tags
    case languageTaggedString = 38  // Language-tagged string (RFC 9290)

    // Identifiers
    case identifier = 39            // Identifier

    // Multi-dimensional Arrays (RFC 8746)
    case multiDimArrayRow = 40      // Row-major multi-dimensional array
    case homogeneousArray = 41      // Homogeneous array
    case ipldCid = 42               // IPLD CID

    // Typed Arrays (RFC 8746)
    case uint8TypedArray = 64       // Uint8Array
    case uint16TypedArray = 65      // Uint16Array, big endian
    case uint32TypedArray = 66      // Uint32Array, big endian
    case uint64TypedArray = 67      // Uint64Array, big endian
    case uint8ClampedTypedArray = 68  // Uint8ClampedArray
    case uint16LETypedArray = 69    // Uint16Array, little endian
    case uint32LETypedArray = 70    // Uint32Array, little endian
    case uint64LETypedArray = 71    // Uint64Array, little endian
    case int8TypedArray = 72        // Int8Array
    case int16TypedArray = 73       // Int16Array, big endian
    case int32TypedArray = 74       // Int32Array, big endian
    case int64TypedArray = 75       // Int64Array, big endian
    case int16LETypedArray = 77     // Int16Array, little endian
    case int32LETypedArray = 78     // Int32Array, little endian
    case int64LETypedArray = 79     // Int64Array, little endian
    case float16TypedArray = 80     // Float16Array, big endian
    case float32TypedArray = 81     // Float32Array, big endian
    case float64TypedArray = 82     // Float64Array, big endian
    case float16LETypedArray = 84   // Float16Array, little endian
    case float32LETypedArray = 85   // Float32Array, little endian
    case float64LETypedArray = 86   // Float64Array, little endian

    // Mathematical Values
    case rationalNumber = 30        // Rational number [numerator, denominator]

    // Self-Describe CBOR
    case selfDescribeCBOR = 55799   // Self-describe CBOR
}

public enum CBORError: Error, LocalizedError {
    case invalidFormat(String)
    case unexpectedEnd
    case wrongTypeInsideIndefiniteLength
    case tooLongIndefiniteLength
    case incorrectUTF8String
    case nonStringKeyInMap
    case duplicateMapKey
    case unsupportedType
    case invalidFloatingPoint
    case tagNotSupported(UInt64)
    case depthLimitExceeded
    case invalidIndefiniteLength
    case malformedData(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFormat(let msg):
            return "Invalid CBOR format: \(msg)"
        case .unexpectedEnd:
            return "Unexpected end of CBOR data"
        case .wrongTypeInsideIndefiniteLength:
            return "Wrong type inside indefinite length item"
        case .tooLongIndefiniteLength:
            return "Indefinite length item too long"
        case .incorrectUTF8String:
            return "Invalid UTF-8 string"
        case .nonStringKeyInMap:
            return "Non-string key in map when string keys required"
        case .duplicateMapKey:
            return "Duplicate key in map"
        case .unsupportedType:
            return "Unsupported CBOR type"
        case .invalidFloatingPoint:
            return "Invalid floating point value"
        case .tagNotSupported(let tag):
            return "CBOR tag \(tag) not supported"
        case .depthLimitExceeded:
            return "Maximum nesting depth exceeded"
        case .invalidIndefiniteLength:
            return "Invalid indefinite-length item"
        case .malformedData(let msg):
            return "Malformed CBOR data: \(msg)"
        }
    }
}