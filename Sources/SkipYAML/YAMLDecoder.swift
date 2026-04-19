// Copyright 2024-2026 Skip
// SPDX-License-Identifier: MPL-2.0

// Codable support requires Swift Foundation protocols that don't transpile to Kotlin.
// The core YAMLValue parser/emitter works on both platforms.
#if !SKIP
import Foundation

/// Decodes `Decodable` types from YAML strings or data.
public final class YAMLDecoder {
    public init() {}

    /// Decode a `Decodable` type from a YAML string.
    public func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        let value = try YAMLValue.parse(string)
        let decoder = _YAMLValueDecoder(value: value, codingPath: [])
        return try T(from: decoder)
    }

    /// Decode a `Decodable` type from UTF-8 YAML data.
    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard let string = String(data: data, encoding: .utf8) else {
            throw YAMLError.decodingError("Invalid UTF-8 data")
        }
        return try decode(type, from: string)
    }
}

// MARK: - Internal Decoder

private final class _YAMLValueDecoder: Decoder {
    let value: YAMLValue
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] = [:]

    init(value: YAMLValue, codingPath: [CodingKey]) {
        self.value = value
        self.codingPath = codingPath
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard case .mapping(let map) = value else {
            throw DecodingError.typeMismatch(
                [String: Any].self,
                DecodingError.Context(codingPath: codingPath, debugDescription: "Expected mapping but found \(describeType(value))")
            )
        }
        return KeyedDecodingContainer(_YAMLKeyedDecodingContainer<Key>(map: map, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .sequence(let arr) = value else {
            throw DecodingError.typeMismatch(
                [Any].self,
                DecodingError.Context(codingPath: codingPath, debugDescription: "Expected sequence but found \(describeType(value))")
            )
        }
        return _YAMLUnkeyedDecodingContainer(values: arr, codingPath: codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return _YAMLSingleValueDecodingContainer(value: value, codingPath: codingPath)
    }

    private func describeType(_ v: YAMLValue) -> String {
        switch v {
        case .null: return "null"
        case .bool: return "bool"
        case .int: return "int"
        case .double: return "double"
        case .string: return "string"
        case .sequence: return "sequence"
        case .mapping: return "mapping"
        }
    }
}

// MARK: - Keyed Container

private final class _YAMLKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K

    let map: YAMLMapping
    var codingPath: [CodingKey]

    var allKeys: [K] {
        var keys: [K] = []
        for entry in map.entries {
            if let str = entry.key.stringValue, let key = K(stringValue: str) {
                keys.append(key)
            }
        }
        return keys
    }

    init(map: YAMLMapping, codingPath: [CodingKey]) {
        self.map = map
        self.codingPath = codingPath
    }

    func contains(_ key: K) -> Bool {
        return map.value(forKey: key.stringValue) != nil
    }

    private func getValue(forKey key: K) throws -> YAMLValue {
        guard let value = map.value(forKey: key.stringValue) else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(codingPath: codingPath, debugDescription: "No value associated with key '\(key.stringValue)'")
            )
        }
        return value
    }

    func decodeNil(forKey key: K) throws -> Bool {
        guard let value = map.value(forKey: key.stringValue) else { return true }
        return value.isNull
    }

    func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
        let value = try getValue(forKey: key)
        guard let b = decodeBool(from: value) else {
            throw typeMismatch(type, value: value, key: key)
        }
        return b
    }

    func decode(_ type: String.Type, forKey key: K) throws -> String {
        let value = try getValue(forKey: key)
        guard let s = decodeString(from: value) else {
            throw typeMismatch(type, value: value, key: key)
        }
        return s
    }

    func decode(_ type: Double.Type, forKey key: K) throws -> Double {
        let value = try getValue(forKey: key)
        guard let d = decodeDouble(from: value) else {
            throw typeMismatch(type, value: value, key: key)
        }
        return d
    }

    func decode(_ type: Float.Type, forKey key: K) throws -> Float {
        let value = try getValue(forKey: key)
        guard let d = decodeDouble(from: value) else {
            throw typeMismatch(type, value: value, key: key)
        }
        return Float(d)
    }

    func decode(_ type: Int.Type, forKey key: K) throws -> Int {
        let value = try getValue(forKey: key)
        guard let i = decodeInt(from: value) else {
            throw typeMismatch(type, value: value, key: key)
        }
        return i
    }

    func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 {
        let value = try getValue(forKey: key)
        guard let i = decodeInt(from: value) else { throw typeMismatch(type, value: value, key: key) }
        return Int8(i)
    }

    func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 {
        let value = try getValue(forKey: key)
        guard let i = decodeInt(from: value) else { throw typeMismatch(type, value: value, key: key) }
        return Int16(i)
    }

    func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 {
        let value = try getValue(forKey: key)
        guard let i = decodeInt(from: value) else { throw typeMismatch(type, value: value, key: key) }
        return Int32(i)
    }

    func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 {
        let value = try getValue(forKey: key)
        guard let i = decodeInt(from: value) else { throw typeMismatch(type, value: value, key: key) }
        return Int64(i)
    }

    func decode(_ type: UInt.Type, forKey key: K) throws -> UInt {
        let value = try getValue(forKey: key)
        guard let i = decodeInt(from: value) else { throw typeMismatch(type, value: value, key: key) }
        return UInt(i)
    }

    func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 {
        let value = try getValue(forKey: key)
        guard let i = decodeInt(from: value) else { throw typeMismatch(type, value: value, key: key) }
        return UInt8(i)
    }

    func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 {
        let value = try getValue(forKey: key)
        guard let i = decodeInt(from: value) else { throw typeMismatch(type, value: value, key: key) }
        return UInt16(i)
    }

    func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 {
        let value = try getValue(forKey: key)
        guard let i = decodeInt(from: value) else { throw typeMismatch(type, value: value, key: key) }
        return UInt32(i)
    }

    func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 {
        let value = try getValue(forKey: key)
        guard let i = decodeInt(from: value) else { throw typeMismatch(type, value: value, key: key) }
        return UInt64(i)
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
        let value = try getValue(forKey: key)
        var path = codingPath
        path.append(key)
        let decoder = _YAMLValueDecoder(value: value, codingPath: path)
        return try T(from: decoder)
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> {
        let value = try getValue(forKey: key)
        guard case .mapping(let nestedMap) = value else {
            throw typeMismatch([String: Any].self, value: value, key: key)
        }
        var path = codingPath
        path.append(key)
        return KeyedDecodingContainer(_YAMLKeyedDecodingContainer<NestedKey>(map: nestedMap, codingPath: path))
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        let value = try getValue(forKey: key)
        guard case .sequence(let arr) = value else {
            throw typeMismatch([Any].self, value: value, key: key)
        }
        var path = codingPath
        path.append(key)
        return _YAMLUnkeyedDecodingContainer(values: arr, codingPath: path)
    }

    func superDecoder() throws -> Decoder {
        let key = K(stringValue: "super")!
        let value = map.value(forKey: "super") ?? .null
        var path = codingPath
        path.append(key)
        return _YAMLValueDecoder(value: value, codingPath: path)
    }

    func superDecoder(forKey key: K) throws -> Decoder {
        let value = try getValue(forKey: key)
        var path = codingPath
        path.append(key)
        return _YAMLValueDecoder(value: value, codingPath: path)
    }

    private func typeMismatch<T>(_ type: T.Type, value: YAMLValue, key: K) -> DecodingError {
        var path = codingPath
        path.append(key)
        return DecodingError.typeMismatch(type, DecodingError.Context(codingPath: path, debugDescription: "Expected \(type) but found \(value)"))
    }
}

// MARK: - Unkeyed Container

private final class _YAMLUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let values: [YAMLValue]
    var codingPath: [CodingKey]
    var currentIndex: Int = 0
    var count: Int? { values.count }
    var isAtEnd: Bool { currentIndex >= values.count }

    init(values: [YAMLValue], codingPath: [CodingKey]) {
        self.values = values
        self.codingPath = codingPath
    }

    private func nextValue() throws -> YAMLValue {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                YAMLValue.self,
                DecodingError.Context(codingPath: codingPath, debugDescription: "Unkeyed container is at end (index \(currentIndex), count \(values.count))")
            )
        }
        let value = values[currentIndex]
        currentIndex += 1
        return value
    }

    func decodeNil() throws -> Bool {
        guard !isAtEnd else { return true }
        if values[currentIndex].isNull {
            currentIndex += 1
            return true
        }
        return false
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        let value = try nextValue()
        guard let b = decodeBool(from: value) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Bool"))
        }
        return b
    }

    func decode(_ type: String.Type) throws -> String {
        let value = try nextValue()
        guard let s = decodeString(from: value) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected String"))
        }
        return s
    }

    func decode(_ type: Double.Type) throws -> Double {
        let value = try nextValue()
        guard let d = decodeDouble(from: value) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Double"))
        }
        return d
    }

    func decode(_ type: Float.Type) throws -> Float {
        let value = try nextValue()
        guard let d = decodeDouble(from: value) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Float"))
        }
        return Float(d)
    }

    func decode(_ type: Int.Type) throws -> Int {
        let value = try nextValue()
        guard let i = decodeInt(from: value) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int"))
        }
        return i
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        let value = try nextValue()
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int8")) }
        return Int8(i)
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        let value = try nextValue()
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int16")) }
        return Int16(i)
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        let value = try nextValue()
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int32")) }
        return Int32(i)
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        let value = try nextValue()
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int64")) }
        return Int64(i)
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        let value = try nextValue()
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected UInt")) }
        return UInt(i)
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        let value = try nextValue()
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected UInt8")) }
        return UInt8(i)
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        let value = try nextValue()
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected UInt16")) }
        return UInt16(i)
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        let value = try nextValue()
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected UInt32")) }
        return UInt32(i)
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        let value = try nextValue()
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected UInt64")) }
        return UInt64(i)
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let value = try nextValue()
        let decoder = _YAMLValueDecoder(value: value, codingPath: codingPath)
        return try T(from: decoder)
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        let value = try nextValue()
        guard case .mapping(let map) = value else {
            throw DecodingError.typeMismatch([String: Any].self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected mapping"))
        }
        return KeyedDecodingContainer(_YAMLKeyedDecodingContainer<NestedKey>(map: map, codingPath: codingPath))
    }

    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let value = try nextValue()
        guard case .sequence(let arr) = value else {
            throw DecodingError.typeMismatch([Any].self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected sequence"))
        }
        return _YAMLUnkeyedDecodingContainer(values: arr, codingPath: codingPath)
    }

    func superDecoder() throws -> Decoder {
        let value = try nextValue()
        return _YAMLValueDecoder(value: value, codingPath: codingPath)
    }
}

// MARK: - Single Value Container

private final class _YAMLSingleValueDecodingContainer: SingleValueDecodingContainer {
    let value: YAMLValue
    var codingPath: [CodingKey]

    init(value: YAMLValue, codingPath: [CodingKey]) {
        self.value = value
        self.codingPath = codingPath
    }

    func decodeNil() -> Bool {
        return value.isNull
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        guard let b = decodeBool(from: value) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Bool"))
        }
        return b
    }

    func decode(_ type: String.Type) throws -> String {
        guard let s = decodeString(from: value) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected String"))
        }
        return s
    }

    func decode(_ type: Double.Type) throws -> Double {
        guard let d = decodeDouble(from: value) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Double"))
        }
        return d
    }

    func decode(_ type: Float.Type) throws -> Float {
        guard let d = decodeDouble(from: value) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Float"))
        }
        return Float(d)
    }

    func decode(_ type: Int.Type) throws -> Int {
        guard let i = decodeInt(from: value) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int"))
        }
        return i
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int8")) }
        return Int8(i)
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int16")) }
        return Int16(i)
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int32")) }
        return Int32(i)
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int64")) }
        return Int64(i)
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected UInt")) }
        return UInt(i)
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected UInt8")) }
        return UInt8(i)
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected UInt16")) }
        return UInt16(i)
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected UInt32")) }
        return UInt32(i)
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        guard let i = decodeInt(from: value) else { throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected UInt64")) }
        return UInt64(i)
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let decoder = _YAMLValueDecoder(value: value, codingPath: codingPath)
        return try T(from: decoder)
    }
}

// MARK: - Type Coercion Helpers

private func decodeBool(from value: YAMLValue) -> Bool? {
    switch value {
    case .bool(let b): return b
    case .int(let i): return i != 0
    case .string(let s):
        let lower = s.lowercased()
        if lower == "true" || lower == "yes" || lower == "on" { return true }
        if lower == "false" || lower == "no" || lower == "off" { return false }
        return nil
    default: return nil
    }
}

private func decodeString(from value: YAMLValue) -> String? {
    switch value {
    case .string(let s): return s
    case .bool(let b): return b ? "true" : "false"
    case .int(let i): return "\(i)"
    case .double(let d): return "\(d)"
    case .null: return nil
    default: return nil
    }
}

private func decodeInt(from value: YAMLValue) -> Int? {
    switch value {
    case .int(let i): return i
    case .double(let d): return Int(d)
    case .string(let s): return Int(s)
    case .bool(let b): return b ? 1 : 0
    default: return nil
    }
}

private func decodeDouble(from value: YAMLValue) -> Double? {
    switch value {
    case .double(let d): return d
    case .int(let i): return Double(i)
    case .string(let s): return Double(s)
    default: return nil
    }
}
#endif // !SKIP
