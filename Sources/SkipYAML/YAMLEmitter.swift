// Copyright 2024-2026 Skip
// SPDX-License-Identifier: MPL-2.0

#if !SKIP
import Foundation
#else
import SkipFoundation
#endif

/// Serializes `YAMLValue` to YAML string representation.
public final class YAMLEmitter {
    /// Whether to sort mapping keys alphabetically.
    public var sortKeys: Bool
    /// Number of spaces per indentation level.
    public var indentWidth: Int
    /// Default scalar style for strings that need quoting.
    public var defaultStringStyle: ScalarStyle
    /// Line width for flow collections (0 = no limit).
    public var lineWidth: Int

    /// Scalar quoting style.
    public enum ScalarStyle {
        case plain
        case singleQuoted
        case doubleQuoted
        case literal
        case folded
    }

    public init(sortKeys: Bool = false, indentWidth: Int = 2, defaultStringStyle: ScalarStyle = .doubleQuoted, lineWidth: Int = 80) {
        self.sortKeys = sortKeys
        self.indentWidth = indentWidth
        self.defaultStringStyle = defaultStringStyle
        self.lineWidth = lineWidth
    }

    /// Emit a single YAML document.
    public func emit(_ value: YAMLValue) -> String {
        var output = ""
        emitNode(value, to: &output, indent: 0, isRoot: true)
        // Ensure trailing newline
        if !output.isEmpty && !output.hasSuffix("\n") {
            output += "\n"
        }
        return output
    }

    /// Emit multiple YAML documents.
    public func emitAll(_ documents: [YAMLValue]) -> String {
        if documents.isEmpty { return "" }
        if documents.count == 1 {
            return emit(documents[0])
        }

        var output = ""
        for i in 0..<documents.count {
            if i > 0 || true {
                output += "---\n"
            }
            emitNode(documents[i], to: &output, indent: 0, isRoot: true)
            if !output.hasSuffix("\n") {
                output += "\n"
            }
        }
        return output
    }

    // MARK: - Node Emission

    private func emitNode(_ value: YAMLValue, to output: inout String, indent: Int, isRoot: Bool) {
        switch value {
        case .null:
            output += "null"
        case .bool(let v):
            output += v ? "true" : "false"
        case .int(let v):
            output += "\(v)"
        case .double(let v):
            if v.isNaN {
                output += ".nan"
            } else if v.isInfinite {
                output += v > 0.0 ? ".inf" : "-.inf"
            } else {
                let s = formatDouble(v)
                output += s
            }
        case .string(let v):
            emitString(v, to: &output, indent: indent)
        case .sequence(let arr):
            emitSequence(arr, to: &output, indent: indent, isRoot: isRoot)
        case .mapping(let map):
            emitMapping(map, to: &output, indent: indent, isRoot: isRoot)
        }
    }

    private func formatDouble(_ v: Double) -> String {
        // Ensure the output has a decimal point
        let s = "\(v)"
        if s.contains(".") || s.contains("e") || s.contains("E") {
            return s
        }
        return s + ".0"
    }

    // MARK: - String Emission

    private func emitString(_ value: String, to output: inout String, indent: Int) {
        if value.isEmpty {
            output += "''"
            return
        }

        // Check if the string can be emitted as a plain scalar
        if canBePlain(value) {
            output += value
            return
        }

        // Check if single quoting suffices (no control characters)
        if canBeSingleQuoted(value) {
            output += "'"
            output += value.replacingOccurrences(of: "'", with: "''")
            output += "'"
            return
        }

        // Use double quoting
        emitDoubleQuoted(value, to: &output)
    }

    private func canBePlain(_ value: String) -> Bool {
        if value.isEmpty { return false }

        // Cannot start with indicator characters
        let first = value[value.startIndex]
        let indicators: [Character] = ["-", "?", ":", ",", "[", "]", "{", "}", "#", "&", "*", "!", "|", ">", "'", "\"", "%", "@", "`"]
        if indicators.contains(first) { return false }

        // Cannot be a reserved word
        let reserved = ["null", "Null", "NULL", "~",
                        "true", "True", "TRUE",
                        "false", "False", "FALSE",
                        ".inf", "+.inf", "-.inf", ".nan",
                        ".Inf", "+.Inf", "-.Inf", ".NaN",
                        ".INF", "+.INF", "-.INF", ".NAN"]
        if reserved.contains(value) { return false }

        // Cannot look like a number
        if looksLikeNumber(value) { return false }

        // Cannot contain certain patterns
        for ch in value {
            if ch == "\n" || ch == "\r" || ch == "\t" { return false }
            if ch == ":" || ch == "#" { return false }
        }

        // Cannot have trailing space
        if value.hasSuffix(" ") { return false }

        return true
    }

    private func looksLikeNumber(_ value: String) -> Bool {
        var s = value
        if s.hasPrefix("-") || s.hasPrefix("+") {
            s = String(s.dropFirst())
        }
        if s.isEmpty { return false }

        // Check for integer
        var allDigits = true
        for ch in s {
            if ch < "0" || ch > "9" { allDigits = false; break }
        }
        if allDigits { return true }

        // Check for float
        if s.contains(".") {
            let parts = s.split(separator: ".", maxSplits: 2)
            if parts.count == 2 {
                var valid = true
                for part in parts {
                    for ch in part {
                        if ch < "0" || ch > "9" { valid = false; break }
                    }
                    if !valid { break }
                }
                if valid { return true }
            }
        }

        // Check for hex/octal
        if s.hasPrefix("0x") || s.hasPrefix("0o") { return true }

        return false
    }

    private func canBeSingleQuoted(_ value: String) -> Bool {
        for ch in value {
            // Control characters (except newline which gets folded)
            if ch < "\u{0020}" && ch != "\n" {
                return false
            }
        }
        return true
    }

    private func emitDoubleQuoted(_ value: String, to output: inout String) {
        output += "\""
        for ch in value {
            switch ch {
            case "\"": output += "\\\""
            case "\\": output += "\\\\"
            case "\n": output += "\\n"
            case "\r": output += "\\r"
            case "\t": output += "\\t"
            case "\u{0000}": output += "\\0"
            case "\u{0007}": output += "\\a"
            case "\u{0008}": output += "\\b"
            case "\u{000B}": output += "\\v"
            case "\u{000C}": output += "\\f"
            case "\u{001B}": output += "\\e"
            case "\u{0085}": output += "\\N"
            case "\u{00A0}": output += "\\_"
            case "\u{2028}": output += "\\L"
            case "\u{2029}": output += "\\P"
            default:
                output += String(ch)
            }
        }
        output += "\""
    }

    // MARK: - Sequence Emission

    private func emitSequence(_ items: [YAMLValue], to output: inout String, indent: Int, isRoot: Bool) {
        if items.isEmpty {
            output += "[]"
            return
        }

        // Use flow style for simple short sequences
        if shouldUseFlowSequence(items) {
            emitFlowSequence(items, to: &output)
            return
        }

        // Block style - ensure we start on a new line
        if !output.isEmpty && !output.hasSuffix("\n") {
            output += "\n"
        }

        let prefix = makeIndent(indent)
        for i in 0..<items.count {
            output += prefix
            output += "- "
            let item = items[i]
            if isCollection(item) {
                if isMapping(item) {
                    // First key goes on same line as dash
                    emitNode(item, to: &output, indent: indent + indentWidth, isRoot: false)
                } else {
                    output += "\n"
                    emitNode(item, to: &output, indent: indent + indentWidth, isRoot: true)
                }
            } else {
                emitNode(item, to: &output, indent: indent + indentWidth, isRoot: false)
            }
            if !output.hasSuffix("\n") {
                output += "\n"
            }
        }
    }

    private func shouldUseFlowSequence(_ items: [YAMLValue]) -> Bool {
        if items.count > 10 { return false }
        for item in items {
            switch item {
            case .sequence, .mapping: return false
            case .string(let s):
                if s.count > 40 { return false }
                if s.contains("\n") { return false }
            default: break
            }
        }
        return false // prefer block style by default
    }

    private func emitFlowSequence(_ items: [YAMLValue], to output: inout String) {
        output += "["
        for i in 0..<items.count {
            if i > 0 { output += ", " }
            emitNode(items[i], to: &output, indent: 0, isRoot: false)
        }
        output += "]"
    }

    // MARK: - Mapping Emission

    private func emitMapping(_ map: YAMLMapping, to output: inout String, indent: Int, isRoot: Bool) {
        if map.isEmpty {
            output += "{}"
            return
        }

        let entries: [YAMLMapEntry]
        if sortKeys {
            entries = map.entries.sorted { a, b in
                let aKey = a.key.stringValue ?? "\(a.key)"
                let bKey = b.key.stringValue ?? "\(b.key)"
                return aKey < bKey
            }
        } else {
            entries = map.entries
        }

        // For mappings as sequence items, the first key is inline after "- "
        // For standalone mappings, ensure each entry is on its own line
        let inline = !isRoot && !output.hasSuffix("\n") && !output.isEmpty
        if !inline && !output.isEmpty && !output.hasSuffix("\n") {
            output += "\n"
        }

        let prefix = makeIndent(indent)
        for i in 0..<entries.count {
            let entry = entries[i]
            if i == 0 && inline {
                // First key inline (after "- " in a sequence)
            } else {
                output += prefix
            }

            // Emit key
            emitNode(entry.key, to: &output, indent: indent, isRoot: false)
            output += ":"

            // Emit value
            let val = entry.value
            if isCollection(val) {
                output += "\n"
                emitNode(val, to: &output, indent: indent + indentWidth, isRoot: true)
            } else {
                output += " "
                emitNode(val, to: &output, indent: indent + indentWidth, isRoot: false)
            }

            if !output.hasSuffix("\n") {
                output += "\n"
            }
        }
    }

    // MARK: - Helpers

    private func makeIndent(_ n: Int) -> String {
        var result = ""
        for _ in 0..<n {
            result += " "
        }
        return result
    }

    private func isCollection(_ value: YAMLValue) -> Bool {
        switch value {
        case .sequence(let arr): return !arr.isEmpty
        case .mapping(let map): return !map.isEmpty
        default: return false
        }
    }

    private func isMapping(_ value: YAMLValue) -> Bool {
        if case .mapping = value { return true }
        return false
    }
}

