import Foundation

public enum CBORValue: Equatable {
	case unsigned(UInt64)
	case negative(Int64)
	case byteString(Data)
	case textString(String)
	case array([CBORValue])
	case map([CBORKey: CBORValue])
	case tagged(UInt64, Box<CBORValue>)
	case simple(SimpleValue)
	case float16(Float16)
	case float32(Float)
	case float64(Double)
	case `break`

	public enum SimpleValue: UInt8, Equatable {
		case `false` = 20
		case `true` = 21
		case null = 22
		case undefined = 23
	}
}

public struct CBORKey: Hashable, Equatable {
	let value: CBORValue

	public init(_ value: CBORValue) {
		self.value = value
	}

	public static func == (lhs: CBORKey, rhs: CBORKey) -> Bool {
		lhs.value == rhs.value
	}

	public func hash(into hasher: inout Hasher) {
		switch value {
		case let .unsigned(val):
			hasher.combine(0)
			hasher.combine(val)
		case let .negative(val):
			hasher.combine(1)
			hasher.combine(val)
		case let .byteString(data):
			hasher.combine(2)
			hasher.combine(data)
		case let .textString(str):
			hasher.combine(3)
			hasher.combine(str)
		case let .array(arr):
			hasher.combine(4)
			hasher.combine(arr.count)
		case let .map(dict):
			hasher.combine(5)
			hasher.combine(dict.count)
		case let .tagged(tag, _):
			hasher.combine(6)
			hasher.combine(tag)
		case let .simple(val):
			hasher.combine(7)
			hasher.combine(val.rawValue)
		case let .float16(val):
			hasher.combine(8)
			hasher.combine(val.bitPattern)
		case let .float32(val):
			hasher.combine(9)
			hasher.combine(val.bitPattern)
		case let .float64(val):
			hasher.combine(10)
			hasher.combine(val.bitPattern)
		case .break:
			hasher.combine(11)
		}
	}
}

public final class Box<T> {
	public let value: T

	public init(_ value: T) {
		self.value = value
	}
}

extension Box: Equatable where T: Equatable {
	public static func == (lhs: Box<T>, rhs: Box<T>) -> Bool {
		lhs.value == rhs.value
	}
}

public extension CBORValue {
	var isUnsigned: Bool {
		if case .unsigned = self { return true }
		return false
	}

	var isNegative: Bool {
		if case .negative = self { return true }
		return false
	}

	var isByteString: Bool {
		if case .byteString = self { return true }
		return false
	}

	var isTextString: Bool {
		if case .textString = self { return true }
		return false
	}

	var isArray: Bool {
		if case .array = self { return true }
		return false
	}

	var isMap: Bool {
		if case .map = self { return true }
		return false
	}

	var isTagged: Bool {
		if case .tagged = self { return true }
		return false
	}

	var isSimple: Bool {
		if case .simple = self { return true }
		return false
	}

	var isFloat: Bool {
		switch self {
		case .float16, .float32, .float64:
			return true
		default:
			return false
		}
	}
}

extension CBORValue: CustomStringConvertible {
	public var description: String {
		switch self {
		case let .unsigned(val):
			return String(val)
		case let .negative(val):
			return String(val)
		case let .byteString(data):
			return "h'\(data.hexEncodedString())'"
		case let .textString(str):
			return "\"\(str)\""
		case let .array(arr):
			return "[\(arr.map { $0.description }.joined(separator: ", "))]"
		case let .map(dict):
			let pairs = dict.map { "\($0.key.value.description): \($0.value.description)" }
			return "{\(pairs.joined(separator: ", "))}"
		case let .tagged(tag, value):
			return "\(tag)(\(value.value.description))"
		case let .simple(val):
			switch val {
			case .false: return "false"
			case .true: return "true"
			case .null: return "null"
			case .undefined: return "undefined"
			}
		case let .float16(val):
			return String(val)
		case let .float32(val):
			return String(val)
		case let .float64(val):
			return String(val)
		case .break:
			return "BREAK"
		}
	}
}

extension Data {
	func hexEncodedString() -> String {
		return map { String(format: "%02x", $0) }.joined()
	}
}
