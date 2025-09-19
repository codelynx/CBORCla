import Foundation

/// Complete IANA CBOR Tags Registry
/// Source: https://www.iana.org/assignments/cbor-tags/
public enum IANATags {

	/// All IANA-registered CBOR tags with their requirements
	public static let registry: [UInt64: TagDefinition] = [
		// RFC 8949 Core Tags (0-5)
		0: TagDefinition(name: "standardDateTime", description: "Standard date/time string", dataItem: .textString),
		1: TagDefinition(name: "epochDateTime", description: "Epoch-based date/time", dataItem: .numeric),
		2: TagDefinition(name: "positiveBignum", description: "Unsigned bignum", dataItem: .byteString()),
		3: TagDefinition(name: "negativeBignum", description: "Negative bignum", dataItem: .byteString()),
		4: TagDefinition(name: "decimalFraction", description: "Decimal fraction", dataItem: .array(elements: 2)),
		5: TagDefinition(name: "bigfloat", description: "Bigfloat", dataItem: .array(elements: 2)),

		// Unassigned: 6-15

		// COSE Tags (RFC 9052)
		16: TagDefinition(
			name: "coseEncrypt0",
			description: "COSE Single Recipient Encrypted Data",
			dataItem: .array()
		),
		17: TagDefinition(name: "coseMac0", description: "COSE Mac w/o Recipients", dataItem: .array()),
		18: TagDefinition(name: "coseSign1", description: "COSE Single Signer Data", dataItem: .array()),
		19: TagDefinition(name: "coseMac", description: "COSE Mac w/ Recipients", dataItem: .array()),

		// Unassigned: 20

		// Expected Conversions (21-23)
		21: TagDefinition(name: "base64UrlConversion", description: "Expected base64url encoding", dataItem: .any),
		22: TagDefinition(name: "base64Conversion", description: "Expected base64 encoding", dataItem: .any),
		23: TagDefinition(name: "base16Conversion", description: "Expected base16 encoding", dataItem: .any),

		// Embedded CBOR
		24: TagDefinition(name: "encodedCBOR", description: "Encoded CBOR data item", dataItem: .byteString()),

		// String References
		25: TagDefinition(name: "stringReference", description: "Reference to nth string", dataItem: .unsigned),
		26: TagDefinition(name: "perlObject", description: "Serialized Perl object", dataItem: .array()),
		27: TagDefinition(
			name: "genericObject",
			description: "Generic object (class, data)",
			dataItem: .array(elements: 2)
		),
		28: TagDefinition(name: "shareable", description: "Mark value as shareable", dataItem: .any),
		29: TagDefinition(name: "sharedReference", description: "Reference nth marked value", dataItem: .unsigned),
		30: TagDefinition(name: "rationalNumber", description: "Rational number", dataItem: .array(elements: 2)),

		// Unassigned: 31

		// URI and Base Encodings (32-36)
		32: TagDefinition(name: "uri", description: "URI", dataItem: .textString),
		33: TagDefinition(name: "base64Url", description: "base64url-encoded text", dataItem: .textString),
		34: TagDefinition(name: "base64", description: "base64-encoded text", dataItem: .textString),
		35: TagDefinition(name: "regex", description: "Regular expression", dataItem: .textString),
		36: TagDefinition(name: "mimeMessage", description: "MIME message", dataItem: .textString),

		// UUID
		37: TagDefinition(name: "binaryUUID", description: "Binary UUID", dataItem: .byteString(length: 16)),

		// Language-tagged string
		38: TagDefinition(
			name: "languageTaggedString",
			description: "Language-tagged string",
			dataItem: .array(elements: 2)
		),

		// Identifier
		39: TagDefinition(name: "identifier", description: "Identifier", dataItem: .any),

		// Multi-dimensional Arrays (40-41)
		40: TagDefinition(
			name: "multiDimArrayRowMajor",
			description: "Multi-dimensional array, row-major",
			dataItem: .array()
		),
		41: TagDefinition(name: "homogeneousArray", description: "Homogeneous array", dataItem: .array()),

		// IPLD
		42: TagDefinition(name: "ipldContent", description: "IPLD content identifier", dataItem: .byteString()),

		// YANG
		43: TagDefinition(name: "yangBits", description: "YANG bits datatype", dataItem: .any),
		44: TagDefinition(name: "yangEnumeration", description: "YANG enumeration datatype", dataItem: .any),
		45: TagDefinition(name: "yangIdentityref", description: "YANG identityref datatype", dataItem: .any),
		46: TagDefinition(name: "yangInstanceId", description: "YANG instance-identifier", dataItem: .any),
		47: TagDefinition(name: "yangSid", description: "YANG Schema Item iDentifier", dataItem: .unsigned),

		// Network Addresses (52-54)
		52: TagDefinition(name: "ipv4", description: "IPv4 address or prefix", dataItem: .byteString()),
		54: TagDefinition(name: "ipv6", description: "IPv6 address or prefix", dataItem: .byteString()),

		// CBOR Web Token
		61: TagDefinition(name: "cborWebToken", description: "CBOR Web Token", dataItem: .any),

		// Typed Arrays (64-87)
		64: TagDefinition(name: "uint8Array", description: "Uint8Array", dataItem: .byteString()),
		65: TagDefinition(name: "uint16BE", description: "Uint16Array (big endian)", dataItem: .byteString()),
		66: TagDefinition(name: "uint32BE", description: "Uint32Array (big endian)", dataItem: .byteString()),
		67: TagDefinition(name: "uint64BE", description: "Uint64Array (big endian)", dataItem: .byteString()),
		68: TagDefinition(name: "uint8Clamped", description: "Uint8ClampedArray", dataItem: .byteString()),
		69: TagDefinition(name: "uint16LE", description: "Uint16Array (little endian)", dataItem: .byteString()),
		70: TagDefinition(name: "uint32LE", description: "Uint32Array (little endian)", dataItem: .byteString()),
		71: TagDefinition(name: "uint64LE", description: "Uint64Array (little endian)", dataItem: .byteString()),
		72: TagDefinition(name: "sint8Array", description: "Sint8Array", dataItem: .byteString()),
		73: TagDefinition(name: "sint16BE", description: "Sint16Array (big endian)", dataItem: .byteString()),
		74: TagDefinition(name: "sint32BE", description: "Sint32Array (big endian)", dataItem: .byteString()),
		75: TagDefinition(name: "sint64BE", description: "Sint64Array (big endian)", dataItem: .byteString()),
		76: TagDefinition(name: "reserved76", description: "Reserved", dataItem: .any),
		77: TagDefinition(name: "sint16LE", description: "Sint16Array (little endian)", dataItem: .byteString()),
		78: TagDefinition(name: "sint32LE", description: "Sint32Array (little endian)", dataItem: .byteString()),
		79: TagDefinition(name: "sint64LE", description: "Sint64Array (little endian)", dataItem: .byteString()),
		80: TagDefinition(name: "float16BE", description: "Float16Array (big endian)", dataItem: .byteString()),
		81: TagDefinition(name: "float32BE", description: "Float32Array (big endian)", dataItem: .byteString()),
		82: TagDefinition(name: "float64BE", description: "Float64Array (big endian)", dataItem: .byteString()),
		83: TagDefinition(name: "float128BE", description: "Float128Array (big endian)", dataItem: .byteString()),
		84: TagDefinition(name: "float16LE", description: "Float16Array (little endian)", dataItem: .byteString()),
		85: TagDefinition(name: "float32LE", description: "Float32Array (little endian)", dataItem: .byteString()),
		86: TagDefinition(name: "float64LE", description: "Float64Array (little endian)", dataItem: .byteString()),
		87: TagDefinition(name: "float128LE", description: "Float128Array (little endian)", dataItem: .byteString()),

		// COSE Extended
		96: TagDefinition(name: "coseEncrypt", description: "COSE Encrypted Data", dataItem: .array()),
		97: TagDefinition(name: "coseMac", description: "COSE MACed Data", dataItem: .array()),
		98: TagDefinition(name: "coseSign", description: "COSE Signed Data", dataItem: .array()),

		// Date Extensions
		100: TagDefinition(name: "daysSinceEpoch", description: "Days since 1970-01-01", dataItem: .integer),
		101: TagDefinition(name: "alternativeTime", description: "Alternative time representation", dataItem: .any),

		// Geographic
		103: TagDefinition(name: "geographicCoordinates", description: "Geographic Coordinates", dataItem: .array()),
		104: TagDefinition(name: "coordinateReferenceSystem", description: "WKT/SRID CRS", dataItem: .any),

		// Object Identifiers (110-115)
		110: TagDefinition(name: "oidBER", description: "Object ID (BER encoding)", dataItem: .byteString()),
		111: TagDefinition(name: "oidIRI", description: "Object ID (IRI)", dataItem: .textString),
		112: TagDefinition(name: "oidArray", description: "Object ID (array)", dataItem: .array()),

		// PCRE/ECMA Regular Expressions
		120: TagDefinition(name: "singletonArray", description: "Single-element array", dataItem: .any),
		121: TagDefinition(name: "dtString", description: "DT string", dataItem: .any),

		// Binary MIME
		200: TagDefinition(name: "gordianEnvelope", description: "Gordian Envelope", dataItem: .any),
		201: TagDefinition(name: "enclosedCBOR", description: "Enclosed dCBOR", dataItem: .any),

		// String References Extended
		256: TagDefinition(
			name: "stringReferencesNamespace",
			description: "String references namespace",
			dataItem: .any
		),
		257: TagDefinition(name: "binaryMime", description: "Binary MIME message", dataItem: .byteString()),

		// Mathematical Sets
		258: TagDefinition(name: "mathematicalFiniteSet", description: "Mathematical finite set", dataItem: .array()),
		259: TagDefinition(name: "mapWithDuplicateKeys", description: "Map with duplicate keys", dataItem: .array()),

		// Network
		260: TagDefinition(name: "networkAddress", description: "Network Address", dataItem: .byteString()),
		261: TagDefinition(name: "networkPrefix", description: "Network Address Prefix", dataItem: .array(elements: 2)),

		// Embedded JSON
		262: TagDefinition(name: "embeddedJSON", description: "Embedded JSON", dataItem: .byteString()),
		263: TagDefinition(name: "hexString", description: "Hexadecimal string", dataItem: .textString),

		// Internationalized Resource Identifiers
		266: TagDefinition(name: "iri", description: "IRI", dataItem: .textString),
		267: TagDefinition(name: "iriReference", description: "IRI reference", dataItem: .textString),

		// Extended Time (RFC 9581)
		1001: TagDefinition(name: "extendedTime", description: "Extended time", dataItem: .map),
		1002: TagDefinition(name: "duration", description: "Duration", dataItem: .map),
		1003: TagDefinition(name: "period", description: "Period", dataItem: .map),

		// Self-described CBOR
		55799: TagDefinition(name: "selfDescribedCBOR", description: "Self-described CBOR", dataItem: .any),

		// Blockchain Commons UR Types (40000-40999)
		40000: TagDefinition(name: "urBytes", description: "UR bytes", dataItem: .byteString()),
		40001: TagDefinition(name: "urText", description: "UR text", dataItem: .textString),

		// RAINS
		15_309_736: TagDefinition(name: "rainsMessage", description: "RAINS message", dataItem: .array()),

		// Intel FPGA
		4_294_967_296: TagDefinition(name: "intelFPGA", description: "Intel FPGA SPDM Manifest", dataItem: .any),

		// Reserved Invalid
		65535: TagDefinition(name: "invalid16", description: "Invalid (Reserved)", dataItem: .invalid),
		4_294_967_295: TagDefinition(name: "invalid32", description: "Invalid (Reserved)", dataItem: .invalid),
		18_446_744_073_709_551_615: TagDefinition(
			name: "invalid64",
			description: "Invalid (Reserved)",
			dataItem: .invalid
		),
	]

	/// Tag validation levels
	public enum ValidationLevel {
		case strict // Validate all tag content according to spec
		case lenient // Allow unknown tags, validate known ones
		case none // No validation
	}
}

/// Definition of a CBOR tag
public struct TagDefinition {
	public let name: String
	public let description: String
	public let dataItem: DataItemRequirement

	public init(name: String, description: String, dataItem: DataItemRequirement) {
		self.name = name
		self.description = description
		self.dataItem = dataItem
	}
}

/// Data item requirements for CBOR tags
public enum DataItemRequirement {
	case any
	case unsigned
	case integer
	case numeric
	case byteString(length: Int? = nil)
	case textString
	case array(elements: Int? = nil)
	case map
	case tagged(UInt64)
	case invalid

	/// Validate a CBOR value against this requirement
	public func validate(_ value: CBORValue) -> Bool {
		switch self {
		case .any:
			return true

		case .unsigned:
			if case .unsigned = value { return true }
			return false

		case .integer:
			switch value {
			case .unsigned, .negative:
				return true
			default:
				return false
			}

		case .numeric:
			switch value {
			case .unsigned, .negative, .float16, .float32, .float64:
				return true
			default:
				return false
			}

		case let .byteString(requiredLength):
			guard case let .byteString(data) = value else { return false }
			if let length = requiredLength {
				return data.count == length
			}
			return true

		case .textString:
			if case .textString = value { return true }
			return false

		case let .array(requiredElements):
			guard case let .array(arr) = value else { return false }
			if let count = requiredElements {
				return arr.count == count
			}
			return true

		case .map:
			if case .map = value { return true }
			return false

		case let .tagged(requiredTag):
			guard case let .tagged(tag, _) = value else { return false }
			return tag == requiredTag

		case .invalid:
			return false
		}
	}
}

/// Extended validation for CBOR tags
extension CBORReader {

	/// Validate tag content using IANA registry
	func validateTagWithIANA(tag: UInt64, value: CBORValue) throws {
		// Check if tag is in registry
		guard let definition = IANATags.registry[tag] else {
			// Unknown tag - allow but don't validate in lenient mode
			if strictMode {
				throw CBORError.tagNotSupported(tag)
			}
			return
		}

		// Validate data item requirement
		if !definition.dataItem.validate(value) {
			throw CBORError
				.invalidFormat("Tag \(tag) (\(definition.name)) requires \(definition.dataItem), got \(value)")
		}

		// Additional semantic validation for specific tags
		switch tag {
		case 0: // RFC3339 date string
			guard case let .textString(str) = value else { return }
			// Basic RFC3339 format check
			if !str.contains("T"), !str.contains("t") {
				throw CBORError.invalidFormat("Tag 0 requires RFC3339 date/time format")
			}

		case 37: // UUID
			guard case let .byteString(data) = value else { return }
			if data.count != 16 {
				throw CBORError.invalidFormat("Tag 37 (UUID) requires exactly 16 bytes")
			}

		case 38: // Language-tagged string
			guard case let .array(arr) = value, arr.count == 2,
			      case .textString = arr[0],
			      case .textString = arr[1]
			else {
				throw CBORError.invalidFormat("Tag 38 requires [language-tag, text]")
			}

		case 100: // Days since epoch
			switch value {
			case .unsigned, .negative:
				break // Valid integer days
			default:
				throw CBORError.invalidFormat("Tag 100 requires integer days")
			}

		case 260: // Network address
			guard case let .byteString(data) = value else { return }
			if data.count != 4, data.count != 16 {
				throw CBORError.invalidFormat("Tag 260 requires 4 (IPv4) or 16 (IPv6) bytes")
			}

		case 1001, 1002, 1003: // RFC 9581 time extensions
			guard case .map = value else {
				throw CBORError.invalidFormat("Tags 1001-1003 require map")
			}

		default:
			// No additional validation needed
			break
		}
	}
}
