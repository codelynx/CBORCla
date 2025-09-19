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
    case standardDateTime = 0
    case epochDateTime = 1
    case positiveBignum = 2
    case negativeBignum = 3
    case decimalFraction = 4
    case bigfloat = 5
    case base64UrlConversion = 21
    case base64Conversion = 22
    case base16Conversion = 23
    case encodedCBORData = 24
    case uri = 32
    case base64Url = 33
    case base64 = 34
    case regex = 35
    case mimeMessage = 36
    case selfDescribeCBOR = 55799
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