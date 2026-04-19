// Copyright 2024-2026 Skip
// SPDX-License-Identifier: MPL-2.0

// Codable support requires Swift Foundation protocols that don't transpile to Kotlin.
// The core YAMLValue parser/emitter works on both platforms.
#if !SKIP
import Foundation

/// Encodes `Encodable` types to YAML strings.
public final class YAMLEncoder {
    /// Whether to sort mapping keys.
    public var sortKeys: Bool
    /// Number of spaces per indentation level.
    public var indentWidth: Int

    public init(sortKeys: Bool = false, indentWidth: Int = 2) {
        self.sortKeys = sortKeys
        self.indentWidth = indentWidth
    }

    /// Encode a value to a YAML string.
    public func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = _YAMLValueEncoder(codingPath: [])
        try value.encode(to: encoder)
        let yamlValue = encoder.result ?? .null
        let emitter = YAMLEmitter(sortKeys: sortKeys, indentWidth: indentWidth)
        return emitter.emit(yamlValue)
    }

    /// Encode a value to UTF-8 YAML data.
    public func encodeToData<T: Encodable>(_ value: T) throws -> Data {
        let string = try encode(value)
        return Data(string.utf8)
    }
}

// MARK: - Internal Encoder

private final class _YAMLValueEncoder: Encoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] = [:]
    var result: YAMLValue?

    init(codingPath: [CodingKey]) {
        self.codingPath = codingPath
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = _YAMLKeyedEncodingContainer<Key>(codingPath: codingPath, encoder: self)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return _YAMLUnkeyedEncodingContainer(codingPath: codingPath, encoder: self)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return _YAMLSingleValueEncodingContainer(codingPath: codingPath, encoder: self)
    }
}

// MARK: - Keyed Encoding Container

private final class _YAMLKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K

    var codingPath: [CodingKey]
    let encoder: _YAMLValueEncoder
    let map: YAMLMapping

    init(codingPath: [CodingKey], encoder: _YAMLValueEncoder) {
        self.codingPath = codingPath
        self.encoder = encoder
        self.map = YAMLMapping()
        encoder.result = .mapping(map)
    }

    func encodeNil(forKey key: K) throws {
        map.append(key: .string(key.stringValue), value: .null)
    }

    func encode(_ value: Bool, forKey key: K) throws {
        map.append(key: .string(key.stringValue), value: .bool(value))
    }

    func encode(_ value: String, forKey key: K) throws {
        map.append(key: .string(key.stringValue), value: .string(value))
    }

    func encode(_ value: Double, forKey key: K) throws {
        map.append(key: .string(key.stringValue), value: .double(value))
    }

    func encode(_ value: Float, forKey key: K) throws {
        map.append(key: .string(key.stringValue), value: .double(Double(value)))
    }

    func encode(_ value: Int, forKey key: K) throws {
        map.append(key: .string(key.stringValue), value: .int(value))
    }

    func encode(_ value: Int8, forKey key: K) throws {
        map.append(key: .string(key.stringValue), value: .int(Int(value)))
    }

    func encode(_ value: Int16, forKey key: K) throws {
        map.append(key: .string(key.stringValue), value: .int(Int(value)))
    }

    func encode(_ value: Int32, forKey key: K) throws {
        map.append(key: .string(key.stringValue), value: .int(Int(value)))
    }

    func encode(_ value: Int64, forKey key: K) throws {
        map.append(key: .string(key.stringValue), value: .int(Int(value)))
    }

    func encode(_ value: UInt, forKey key: K) throws {
        map.append(key: .string(key.stringValue), value: .int(Int(value)))
    }

    func encode(_ value: UInt8, forKey key: K) throws {
        map.append(key: .string(key.stringValue), value: .int(Int(value)))
    }

    func encode(_ value: UInt16, forKey key: K) throws {
        map.append(key: .string(key.stringValue), value: .int(Int(value)))
    }

    func encode(_ value: UInt32, forKey key: K) throws {
        map.append(key: .string(key.stringValue), value: .int(Int(value)))
    }

    func encode(_ value: UInt64, forKey key: K) throws {
        map.append(key: .string(key.stringValue), value: .int(Int(value)))
    }

    func encode<T: Encodable>(_ value: T, forKey key: K) throws {
        var path = codingPath
        path.append(key)
        let childEncoder = _YAMLValueEncoder(codingPath: path)
        try value.encode(to: childEncoder)
        map.append(key: .string(key.stringValue), value: childEncoder.result ?? .null)
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> {
        var path = codingPath
        path.append(key)
        let childEncoder = _YAMLValueEncoder(codingPath: path)
        let container = _YAMLKeyedEncodingContainer<NestedKey>(codingPath: path, encoder: childEncoder)
        map.append(key: .string(key.stringValue), value: .mapping(container.map))
        return KeyedEncodingContainer(container)
    }

    func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        var path = codingPath
        path.append(key)
        let childEncoder = _YAMLValueEncoder(codingPath: path)
        let container = _YAMLUnkeyedEncodingContainer(codingPath: path, encoder: childEncoder)
        // We'll set the value after encoding
        map.append(key: .string(key.stringValue), value: .sequence([]))
        return container
    }

    func superEncoder() -> Encoder {
        let childEncoder = _YAMLValueEncoder(codingPath: codingPath)
        map.append(key: .string("super"), value: .null)
        return childEncoder
    }

    func superEncoder(forKey key: K) -> Encoder {
        var path = codingPath
        path.append(key)
        let childEncoder = _YAMLValueEncoder(codingPath: path)
        map.append(key: .string(key.stringValue), value: .null)
        return childEncoder
    }
}

// MARK: - Unkeyed Encoding Container

private final class _YAMLUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    var codingPath: [CodingKey]
    var count: Int = 0
    let encoder: _YAMLValueEncoder
    var items: [YAMLValue] = []

    init(codingPath: [CodingKey], encoder: _YAMLValueEncoder) {
        self.codingPath = codingPath
        self.encoder = encoder
        encoder.result = .sequence([])
    }

    private func addItem(_ value: YAMLValue) {
        items.append(value)
        count += 1
        encoder.result = .sequence(items)
    }

    func encodeNil() throws { addItem(.null) }
    func encode(_ value: Bool) throws { addItem(.bool(value)) }
    func encode(_ value: String) throws { addItem(.string(value)) }
    func encode(_ value: Double) throws { addItem(.double(value)) }
    func encode(_ value: Float) throws { addItem(.double(Double(value))) }
    func encode(_ value: Int) throws { addItem(.int(value)) }
    func encode(_ value: Int8) throws { addItem(.int(Int(value))) }
    func encode(_ value: Int16) throws { addItem(.int(Int(value))) }
    func encode(_ value: Int32) throws { addItem(.int(Int(value))) }
    func encode(_ value: Int64) throws { addItem(.int(Int(value))) }
    func encode(_ value: UInt) throws { addItem(.int(Int(value))) }
    func encode(_ value: UInt8) throws { addItem(.int(Int(value))) }
    func encode(_ value: UInt16) throws { addItem(.int(Int(value))) }
    func encode(_ value: UInt32) throws { addItem(.int(Int(value))) }
    func encode(_ value: UInt64) throws { addItem(.int(Int(value))) }

    func encode<T: Encodable>(_ value: T) throws {
        let childEncoder = _YAMLValueEncoder(codingPath: codingPath)
        try value.encode(to: childEncoder)
        addItem(childEncoder.result ?? .null)
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let childEncoder = _YAMLValueEncoder(codingPath: codingPath)
        let container = _YAMLKeyedEncodingContainer<NestedKey>(codingPath: codingPath, encoder: childEncoder)
        addItem(.mapping(container.map))
        return KeyedEncodingContainer(container)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let childEncoder = _YAMLValueEncoder(codingPath: codingPath)
        let container = _YAMLUnkeyedEncodingContainer(codingPath: codingPath, encoder: childEncoder)
        // We'll link it on completion
        return container
    }

    func superEncoder() -> Encoder {
        let childEncoder = _YAMLValueEncoder(codingPath: codingPath)
        return childEncoder
    }
}

// MARK: - Single Value Encoding Container

private final class _YAMLSingleValueEncodingContainer: SingleValueEncodingContainer {
    var codingPath: [CodingKey]
    let encoder: _YAMLValueEncoder

    init(codingPath: [CodingKey], encoder: _YAMLValueEncoder) {
        self.codingPath = codingPath
        self.encoder = encoder
    }

    func encodeNil() throws { encoder.result = .null }
    func encode(_ value: Bool) throws { encoder.result = .bool(value) }
    func encode(_ value: String) throws { encoder.result = .string(value) }
    func encode(_ value: Double) throws { encoder.result = .double(value) }
    func encode(_ value: Float) throws { encoder.result = .double(Double(value)) }
    func encode(_ value: Int) throws { encoder.result = .int(value) }
    func encode(_ value: Int8) throws { encoder.result = .int(Int(value)) }
    func encode(_ value: Int16) throws { encoder.result = .int(Int(value)) }
    func encode(_ value: Int32) throws { encoder.result = .int(Int(value)) }
    func encode(_ value: Int64) throws { encoder.result = .int(Int(value)) }
    func encode(_ value: UInt) throws { encoder.result = .int(Int(value)) }
    func encode(_ value: UInt8) throws { encoder.result = .int(Int(value)) }
    func encode(_ value: UInt16) throws { encoder.result = .int(Int(value)) }
    func encode(_ value: UInt32) throws { encoder.result = .int(Int(value)) }
    func encode(_ value: UInt64) throws { encoder.result = .int(Int(value)) }

    func encode<T: Encodable>(_ value: T) throws {
        let childEncoder = _YAMLValueEncoder(codingPath: codingPath)
        try value.encode(to: childEncoder)
        encoder.result = childEncoder.result
    }
}
#endif // !SKIP
