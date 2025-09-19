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

public enum CBORTag: UInt64, CaseIterable {
	// MARK: - RFC 8949 Core Tags (0-5)

	case standardDateTime = 0 // Text string in RFC 3339 format
	case epochDateTime = 1 // Numeric epoch-based date/time
	case positiveBignum = 2 // Byte string as unsigned bignum
	case negativeBignum = 3 // Byte string as negative bignum
	case decimalFraction = 4 // Array: [exponent, mantissa]
	case bigfloat = 5 // Array: [exponent, mantissa]

	// MARK: - COSE Tags (16-19, 96-98)

	case coseEncrypt0 = 16 // COSE Single Recipient Encrypted Data
	case coseMac0 = 17 // COSE Mac w/o Recipients
	case coseSign1 = 18 // COSE Single Signer Data
	case coseMac = 19 // COSE Mac w/ Recipients
	case coseEncrypt = 96 // COSE Encrypted Data
	case coseMacMultiple = 97 // COSE MACed Data
	case coseSign = 98 // COSE Signed Data

	// MARK: - Expected Conversions (21-23)

	case base64UrlConversion = 21 // Expected conversion to base64url
	case base64Conversion = 22 // Expected conversion to base64
	case base16Conversion = 23 // Expected conversion to base16

	// MARK: - Embedded Data (24)

	case encodedCBORData = 24 // Embedded CBOR data item

	// MARK: - References and Objects (25-30)

	case stringReference = 25 // Reference to string defined elsewhere
	case perlSerializedObject = 26 // Serialized Perl object
	case genericObject = 27 // Generic object (class, data)
	case shareableValue = 28 // Mark value as shareable
	case sharedReference = 29 // Reference to nth marked value
	case rationalNumber = 30 // Rational number [numerator, denominator]

	// MARK: - Text Formats (32-39)

	case uri = 32 // URI text string
	case base64Url = 33 // Base64url-encoded text string
	case base64 = 34 // Base64-encoded text string
	case regex = 35 // Regular expression text string
	case mimeMessage = 36 // MIME message text string
	case uuid = 37 // Binary UUID (16 bytes)
	case languageTaggedString = 38 // Language-tagged string [lang, text]
	case identifier = 39 // Identifier

	// MARK: - Arrays and Collections (40-42)

	case multiDimArrayRow = 40 // Row-major multi-dimensional array
	case homogeneousArray = 41 // Homogeneous array
	case ipldCid = 42 // IPLD content identifier

	// MARK: - YANG Types (43-47)

	case yangBits = 43 // YANG bits datatype
	case yangEnumeration = 44 // YANG enumeration
	case yangIdentityref = 45 // YANG identityref
	case yangInstanceId = 46 // YANG instance-identifier
	case yangSid = 47 // YANG Schema Item iDentifier

	// MARK: - Network Addresses (52-54)

	case ipv4 = 52 // IPv4 address/prefix
	case ipv6 = 54 // IPv6 address/prefix

	// MARK: - Web Token (61)

	case cborWebToken = 61 // CBOR Web Token (CWT)

	// MARK: - Typed Arrays (64-87)

	case uint8Array = 64 // Uint8Array
	case uint16BE = 65 // Uint16Array, big endian
	case uint32BE = 66 // Uint32Array, big endian
	case uint64BE = 67 // Uint64Array, big endian
	case uint8Clamped = 68 // Uint8ClampedArray
	case uint16LE = 69 // Uint16Array, little endian
	case uint32LE = 70 // Uint32Array, little endian
	case uint64LE = 71 // Uint64Array, little endian
	case sint8Array = 72 // Sint8Array
	case sint16BE = 73 // Sint16Array, big endian
	case sint32BE = 74 // Sint32Array, big endian
	case sint64BE = 75 // Sint64Array, big endian
	case sint16LE = 77 // Sint16Array, little endian
	case sint32LE = 78 // Sint32Array, little endian
	case sint64LE = 79 // Sint64Array, little endian
	case float16BE = 80 // Float16Array, big endian
	case float32BE = 81 // Float32Array, big endian
	case float64BE = 82 // Float64Array, big endian
	case float128BE = 83 // Float128Array, big endian
	case float16LE = 84 // Float16Array, little endian
	case float32LE = 85 // Float32Array, little endian
	case float64LE = 86 // Float64Array, little endian
	case float128LE = 87 // Float128Array, little endian

	// MARK: - Date/Time Extensions (100-101)

	case daysSinceEpoch = 100 // Days since 1970-01-01
	case alternativeTime = 101 // Alternative time representation

	// MARK: - Geographic (103-104)

	case geographicCoords = 103 // Geographic Coordinates
	case coordinateRefSystem = 104 // WKT CRS or SRID

	// MARK: - Object Identifiers (110-112)

	case oidBER = 110 // Object ID (BER encoding)
	case oidIRI = 111 // Object ID (IRI)
	case oidArray = 112 // Object ID (array)

	// MARK: - Extended Types (120-121)

	case singletonArray = 120 // Single-element array wrapper
	case dtString = 121 // DT string

	// MARK: - Gordian/CBOR Extensions (200-201)

	case gordianEnvelope = 200 // Gordian Envelope
	case enclosedCBOR = 201 // Enclosed dCBOR

	// MARK: - Extended References and MIME (256-259)

	case stringRefNamespace = 256 // String references namespace
	case binaryMime = 257 // Binary MIME message
	case mathFiniteSet = 258 // Mathematical finite set
	case mapDuplicateKeys = 259 // Map with duplicate keys

	// MARK: - Network Extended (260-261)

	case networkAddress = 260 // Network address (IPv4/IPv6)
	case networkPrefix = 261 // Network prefix

	// MARK: - Embedded Formats (262-263)

	case embeddedJSON = 262 // Embedded JSON
	case hexString = 263 // Hexadecimal string

	// MARK: - IRIs (266-267)

	case iri = 266 // Internationalized Resource Identifier
	case iriReference = 267 // IRI reference

	// MARK: - RFC 9581 Time Extensions (1001-1003)

	case extendedTime = 1001 // Extended time
	case duration = 1002 // Duration
	case period = 1003 // Period

	// MARK: - Self-Describe CBOR

	case selfDescribeCBOR = 55799 // Self-describe CBOR

	// MARK: - Blockchain Commons (40000-40999)

	case urBytes = 40000 // UR bytes
	case urText = 40001 // UR text

	// MARK: - Special Purpose

	case rainsMessage = 15_309_736 // RAINS message
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
		case let .invalidFormat(msg):
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
		case let .tagNotSupported(tag):
			return "CBOR tag \(tag) not supported"
		case .depthLimitExceeded:
			return "Maximum nesting depth exceeded"
		case .invalidIndefiniteLength:
			return "Invalid indefinite-length item"
		case let .malformedData(msg):
			return "Malformed CBOR data: \(msg)"
		}
	}
}
