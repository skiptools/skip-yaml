// Copyright 2024-2026 Skip
// SPDX-License-Identifier: MPL-2.0

#if !SKIP
import Foundation
#else
import SkipFoundation
#endif

/// Errors that can occur during YAML parsing, emitting, encoding, or decoding.
public enum YAMLError: Error {
    case parseError(_ message: String)
    case emitError(_ message: String)
    case decodingError(_ message: String)
    case encodingError(_ message: String)
}

/// A YAML value representing the core data types in the YAML data model.
public enum YAMLValue: CustomStringConvertible, Sendable {
    /// A null/nil value (`null`, `~`, or empty).
    case null
    /// A boolean value (`true` or `false`).
    case bool(Bool)
    /// An integer value.
    case int(Int)
    /// A floating-point value.
    case double(Double)
    /// A string value.
    case string(String)
    /// An ordered sequence (array) of values.
    case sequence([YAMLValue])
    /// An ordered mapping (dictionary) of key-value pairs.
    case mapping(YAMLMapping)

    public var description: String {
        switch self {
        case .null: return "null"
        case .bool(let v): return "\(v)"
        case .int(let v): return "\(v)"
        case .double(let v): return "\(v)"
        case .string(let v): return v
        case .sequence(let arr):
            let items = arr.map { "\($0)" }
            return "[" + items.joined(separator: ", ") + "]"
        case .mapping(let map):
            let items = map.entries.map { "\($0.key): \($0.value)" }
            return "{" + items.joined(separator: ", ") + "}"
        }
    }
}

/// An ordered collection of key-value pairs representing a YAML mapping.
public final class YAMLMapping: @unchecked Sendable {
    public var entries: [YAMLMapEntry]

    public init(_ entries: [YAMLMapEntry] = []) {
        self.entries = entries
    }

    public var count: Int { entries.count }
    public var isEmpty: Bool { entries.isEmpty }

    public var keys: [YAMLValue] {
        entries.map { $0.key }
    }

    public var values: [YAMLValue] {
        entries.map { $0.value }
    }

    public func value(forKey key: String) -> YAMLValue? {
        for entry in entries {
            if case .string(let k) = entry.key, k == key {
                return entry.value
            }
        }
        return nil
    }

    public func value(forYAMLKey key: YAMLValue) -> YAMLValue? {
        for entry in entries {
            if entry.key == key {
                return entry.value
            }
        }
        return nil
    }

    public func append(key: YAMLValue, value: YAMLValue) {
        entries.append(YAMLMapEntry(key: key, value: value))
    }
}

/// A single key-value pair in a YAML mapping.
public final class YAMLMapEntry: @unchecked Sendable {
    public let key: YAMLValue
    public let value: YAMLValue

    public init(key: YAMLValue, value: YAMLValue) {
        self.key = key
        self.value = value
    }
}

// MARK: - Equatable

extension YAMLValue: Equatable {
    public static func == (lhs: YAMLValue, rhs: YAMLValue) -> Bool {
        switch lhs {
        case .null:
            if case .null = rhs { return true }
            return false
        case .bool(let a):
            if case .bool(let b) = rhs { return a == b }
            return false
        case .int(let a):
            if case .int(let b) = rhs { return a == b }
            return false
        case .double(let a):
            if case .double(let b) = rhs { return a == b }
            return false
        case .string(let a):
            if case .string(let b) = rhs { return a == b }
            return false
        case .sequence(let a):
            if case .sequence(let b) = rhs { return a == b }
            return false
        case .mapping(let a):
            if case .mapping(let b) = rhs {
                let ae = a.entries
                let be = b.entries
                if ae.count != be.count { return false }
                for i in 0..<ae.count {
                    if ae[i].key != be[i].key { return false }
                    if ae[i].value != be[i].value { return false }
                }
                return true
            }
            return false
        }
    }
}

// MARK: - Hashable

extension YAMLValue: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .null:
            hasher.combine(0)
        case .bool(let v):
            hasher.combine(1)
            hasher.combine(v)
        case .int(let v):
            hasher.combine(2)
            hasher.combine(v)
        case .double(let v):
            hasher.combine(3)
            hasher.combine(v)
        case .string(let v):
            hasher.combine(4)
            hasher.combine(v)
        case .sequence(let v):
            hasher.combine(5)
            hasher.combine(v)
        case .mapping(let m):
            hasher.combine(6)
            hasher.combine(m.entries.count)
        }
    }
}

// MARK: - Value Access

extension YAMLValue {
    /// Access a mapping value by string key.
    public subscript(key: String) -> YAMLValue? {
        guard case .mapping(let map) = self else { return nil }
        return map.value(forKey: key)
    }

    /// Access a sequence element by index.
    public subscript(index: Int) -> YAMLValue? {
        guard case .sequence(let arr) = self else { return nil }
        guard index >= 0 && index < arr.count else { return nil }
        return arr[index]
    }

    /// The string value if this is a `.string`, `.bool`, `.int`, `.double`, or `.null`.
    public var stringValue: String? {
        switch self {
        case .string(let v): return v
        case .bool(let v): return "\(v)"
        case .int(let v): return "\(v)"
        case .double(let v): return "\(v)"
        case .null: return nil
        default: return nil
        }
    }

    /// The integer value if this is an `.int`, or an `.string` that can be parsed as int.
    public var intValue: Int? {
        switch self {
        case .int(let v): return v
        case .string(let v): return Int(v)
        case .double(let v): return Int(v)
        case .bool(let v): return v ? 1 : 0
        default: return nil
        }
    }

    /// The double value if this is a `.double`, `.int`, or parseable `.string`.
    public var doubleValue: Double? {
        switch self {
        case .double(let v): return v
        case .int(let v): return Double(v)
        case .string(let v): return Double(v)
        default: return nil
        }
    }

    /// The boolean value if this is a `.bool`.
    public var boolValue: Bool? {
        switch self {
        case .bool(let v): return v
        case .int(let v): return v != 0
        case .string(let v):
            let lower = v.lowercased()
            if lower == "true" || lower == "yes" || lower == "on" { return true }
            if lower == "false" || lower == "no" || lower == "off" { return false }
            return nil
        default: return nil
        }
    }

    /// The array value if this is a `.sequence`.
    public var arrayValue: [YAMLValue]? {
        guard case .sequence(let arr) = self else { return nil }
        return arr
    }

    /// The mapping value if this is a `.mapping`.
    public var mappingValue: YAMLMapping? {
        guard case .mapping(let m) = self else { return nil }
        return m
    }

    /// The number of elements in a sequence or mapping, or nil for scalars.
    public var count: Int? {
        switch self {
        case .sequence(let arr): return arr.count
        case .mapping(let map): return map.count
        default: return nil
        }
    }

    /// Whether this value is null.
    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    /// Whether this value is a scalar (null, bool, int, double, string).
    public var isScalar: Bool {
        switch self {
        case .null, .bool, .int, .double, .string: return true
        default: return false
        }
    }

    /// Whether this value is a collection (sequence or mapping).
    public var isCollection: Bool {
        switch self {
        case .sequence, .mapping: return true
        default: return false
        }
    }
}

// MARK: - Parsing API

extension YAMLValue {
    /// Parse a YAML string and return the first document value.
    /// If the string contains multiple documents, only the first is returned.
    public static func parse(_ string: String) throws -> YAMLValue {
        let parser = YAMLParser(string)
        let docs = try parser.parse()
        return docs.isEmpty ? .null : docs[0]
    }

    /// Parse a YAML string containing potentially multiple documents.
    /// Returns an array of values, one per document.
    public static func parseAll(_ string: String) throws -> [YAMLValue] {
        let parser = YAMLParser(string)
        return try parser.parse()
    }

    /// Parse YAML from UTF-8 data.
    public static func parse(_ data: Data) throws -> YAMLValue {
        guard let string = String(data: data, encoding: .utf8) else {
            throw YAMLError.parseError("Invalid UTF-8 data")
        }
        return try parse(string)
    }

    /// Parse YAML from UTF-8 data, returning all documents.
    public static func parseAll(_ data: Data) throws -> [YAMLValue] {
        guard let string = String(data: data, encoding: .utf8) else {
            throw YAMLError.parseError("Invalid UTF-8 data")
        }
        return try parseAll(string)
    }
}

// MARK: - Emitting API

extension YAMLValue {
    /// Serialize this value to a YAML string.
    public func yamlString(sortKeys: Bool = false, indent: Int = 2) -> String {
        let emitter = YAMLEmitter(sortKeys: sortKeys, indentWidth: indent)
        return emitter.emit(self)
    }

    /// Serialize multiple documents to a YAML string.
    public static func emitAll(_ documents: [YAMLValue], sortKeys: Bool = false, indent: Int = 2) -> String {
        let emitter = YAMLEmitter(sortKeys: sortKeys, indentWidth: indent)
        return emitter.emitAll(documents)
    }
}

// MARK: - ExpressibleBy Literals

#if !SKIP
extension YAMLValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension YAMLValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension YAMLValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension YAMLValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension YAMLValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: YAMLValue...) {
        self = .sequence(Array(elements))
    }
}

extension YAMLValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}
#endif

// MARK: - Module

public class SkipYAMLModule {
}
