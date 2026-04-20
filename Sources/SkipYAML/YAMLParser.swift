// Copyright 2024-2026 Skip
// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Internal YAML parser implementing recursive descent parsing.
/// Supports YAML 1.2 Core Schema with common 1.1 compatibility.
internal final class YAMLParser {
    private let chars: [Character]
    private var pos: Int = 0
    private var line: Int = 1
    private var col: Int = 0
    private var anchors: [String: YAMLValue] = [:]

    init(_ input: String) {
        // Normalize line endings and convert to character array for random access
        let normalized = input.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        self.chars = normalized.map { $0 }
    }

    // MARK: - Character Operations

    private func peek() -> Character? {
        guard pos < chars.count else { return nil }
        return chars[pos]
    }

    private func peekAt(_ offset: Int) -> Character? {
        let idx = pos + offset
        guard idx >= 0 && idx < chars.count else { return nil }
        return chars[idx]
    }

    private func atEnd() -> Bool {
        return pos >= chars.count
    }

    @discardableResult
    private func advance() -> Character {
        let c = chars[pos]
        pos += 1
        if c == "\n" {
            line += 1
            col = 0
        } else {
            col += 1
        }
        return c
    }

    private func advanceBy(_ n: Int) {
        for _ in 0..<n {
            if pos < chars.count {
                advance()
            }
        }
    }

    private func matches(_ s: String) -> Bool {
        let schars = s.map { $0 }
        for i in 0..<schars.count {
            guard let c = peekAt(i), c == schars[i] else { return false }
        }
        return true
    }

    private func error(_ message: String) -> YAMLError {
        return YAMLError.parseError("\(message) at line \(line), column \(col)")
    }

    // MARK: - Whitespace and Comment Handling

    private func skipSpaces() {
        while let c = peek(), c == " " || c == "\t" {
            advance()
        }
    }

    private func skipSpacesAndTabs() {
        while let c = peek(), c == " " || c == "\t" {
            advance()
        }
    }

    private func skipInlineWhitespace() {
        while let c = peek(), c == " " || c == "\t" {
            advance()
        }
    }

    private func skipComment() {
        if let c = peek(), c == "#" {
            while let ch = peek(), ch != "\n" {
                advance()
            }
        }
    }

    private func skipWhitespaceAndComments() {
        while !atEnd() {
            let c = peek()!
            if c == " " || c == "\t" {
                advance()
            } else if c == "\n" {
                advance()
            } else if c == "#" {
                while let ch = peek(), ch != "\n" {
                    advance()
                }
            } else {
                break
            }
        }
    }

    /// Skip blank lines and comments, returning the column of the next content.
    private func skipToContent() -> Int {
        skipWhitespaceAndComments()
        return col
    }

    // MARK: - BOM and Directive Handling

    private func skipBOM() {
        if let c = peek(), c == "\u{FEFF}" {
            advance()
        }
    }

    private func skipDirectives() {
        while let c = peek(), c == "%" {
            // Skip directive line
            while let ch = peek(), ch != "\n" {
                advance()
            }
            if let ch = peek(), ch == "\n" {
                advance()
            }
        }
    }

    // MARK: - Document Markers

    private func isDocumentStart() -> Bool {
        guard col == 0 || (pos - col) == 0 || isAtLineStart() else { return false }
        return matches("---") && (peekAt(3) == nil || peekAt(3) == " " || peekAt(3) == "\n" || peekAt(3) == "\t")
    }

    private func isDocumentEnd() -> Bool {
        guard col == 0 || isAtLineStart() else { return false }
        return matches("...") && (peekAt(3) == nil || peekAt(3) == " " || peekAt(3) == "\n" || peekAt(3) == "\t")
    }

    private func isAtLineStart() -> Bool {
        return col == 0
    }

    private func consumeDocumentStart() {
        if isDocumentStart() {
            advanceBy(3)
            skipInlineWhitespace()
            skipComment()
            if let c = peek(), c == "\n" {
                advance()
            }
        }
    }

    private func consumeDocumentEnd() {
        if isDocumentEnd() {
            advanceBy(3)
            skipInlineWhitespace()
            skipComment()
            if let c = peek(), c == "\n" {
                advance()
            }
        }
    }

    // MARK: - Stream Parsing

    func parse() throws -> [YAMLValue] {
        var documents: [YAMLValue] = []
        skipBOM()

        while !atEnd() {
            skipWhitespaceAndComments()
            if atEnd() { break }

            skipDirectives()
            skipWhitespaceAndComments()
            if atEnd() { break }

            let hadExplicitStart = isDocumentStart()
            if hadExplicitStart {
                consumeDocumentStart()
                skipWhitespaceAndComments()
            }

            if atEnd() {
                if hadExplicitStart {
                    documents.append(.null)
                }
                break
            }

            // Check for document end immediately after start
            if isDocumentEnd() {
                documents.append(.null)
                consumeDocumentEnd()
                continue
            }

            // Check for another document start immediately
            if isDocumentStart() {
                documents.append(.null)
                continue
            }

            let doc = try parseBlockNode(minIndent: -1)
            documents.append(doc)

            skipWhitespaceAndComments()
            if isDocumentEnd() {
                consumeDocumentEnd()
            }
        }

        if documents.isEmpty {
            documents.append(.null)
        }

        return documents
    }

    // MARK: - Node Parsing

    private func parseBlockNode(minIndent: Int) throws -> YAMLValue {
        let startCol = skipToContent()
        if atEnd() { return .null }

        // Document markers end the current node
        if isDocumentStart() || isDocumentEnd() {
            return .null
        }

        return try parseNodeAtCurrentPosition(indent: startCol, minIndent: minIndent)
    }

    private func parseNodeAtCurrentPosition(indent: Int, minIndent: Int) throws -> YAMLValue {
        guard let c = peek() else { return .null }

        // Handle anchor
        if c == "&" {
            return try parseAnchor(indent: indent, minIndent: minIndent)
        }

        // Handle alias
        if c == "*" {
            return try parseAlias()
        }

        // Handle tag
        if c == "!" {
            return try parseTag(indent: indent, minIndent: minIndent)
        }

        // Flow collections
        if c == "[" { return try parseFlowSequence() }
        if c == "{" { return try parseFlowMapping() }

        // Block scalars - use minIndent so content indentation is relative to parent
        if c == "|" { return try parseLiteralBlockScalar(indent: minIndent) }
        if c == ">" { return try parseFoldedBlockScalar(indent: minIndent) }

        // Block sequence
        if c == "-" && isBlockSequenceIndicator() {
            return try parseBlockSequence(indent: indent)
        }

        // Explicit key
        if c == "?" && (peekAt(1) == nil || peekAt(1) == " " || peekAt(1) == "\n" || peekAt(1) == "\t") {
            return try parseBlockMappingWithExplicitKey(indent: indent)
        }

        // Check for block mapping (look for key: pattern) - must come before quoted scalars
        // so that quoted keys like "key": value are detected
        if looksLikeMappingAtCurrentLine(fromCol: indent) {
            return try parseBlockMapping(indent: indent)
        }

        // Quoted scalars (not mapping keys - those are handled above)
        if c == "'" { return try resolveQuotedScalar(parseSingleQuotedScalar()) }
        if c == "\"" { return try resolveQuotedScalar(parseDoubleQuotedScalar()) }

        // Plain scalar
        let scalar = try parsePlainScalar(indent: indent, minIndent: minIndent, inFlow: false)
        return resolvePlainScalar(scalar)
    }

    private func isBlockSequenceIndicator() -> Bool {
        let next = peekAt(1)
        return next == nil || next == " " || next == "\n" || next == "\t"
    }

    // MARK: - Block Sequence

    private func parseBlockSequence(indent: Int) throws -> YAMLValue {
        var items: [YAMLValue] = []
        let seqIndent = col

        while !atEnd() {
            // Must be at sequence indentation with '-'
            guard col == seqIndent, let c = peek(), c == "-", isBlockSequenceIndicator() else {
                break
            }

            advance() // consume '-'

            // Skip space after '-'
            if let sp = peek(), sp == " " || sp == "\t" {
                advance()
            }

            let contentCol = col

            // Check for empty value
            if atEnd() {
                items.append(.null)
                break
            }

            if let next = peek(), next == "\n" {
                // Value is on next line or null
                advance()
                skipWhitespaceAndComments()
                if atEnd() || col <= seqIndent || isDocumentStart() || isDocumentEnd() {
                    items.append(.null)
                    continue
                }
                let value = try parseBlockNode(minIndent: seqIndent)
                items.append(value)
            } else if let next = peek(), next == "#" {
                skipComment()
                if let nl = peek(), nl == "\n" { advance() }
                skipWhitespaceAndComments()
                if atEnd() || col <= seqIndent || isDocumentStart() || isDocumentEnd() {
                    items.append(.null)
                    continue
                }
                let value = try parseBlockNode(minIndent: seqIndent)
                items.append(value)
            } else {
                // Value on same line
                let value = try parseNodeAtCurrentPosition(indent: contentCol, minIndent: seqIndent)
                items.append(value)
            }

            // Skip trailing whitespace and comments
            skipInlineWhitespace()
            skipComment()

            // Advance past newline if present
            if let nl = peek(), nl == "\n" {
                advance()
            }

            // Skip to next content
            skipWhitespaceAndComments()

            // Check for document markers
            if isDocumentStart() || isDocumentEnd() {
                break
            }
        }

        return .sequence(items)
    }

    // MARK: - Block Mapping

    private func looksLikeMappingAtCurrentLine(fromCol: Int) -> Bool {
        var i = pos
        var depth = 0
        var inSingleQuote = false
        var inDoubleQuote = false

        while i < chars.count && chars[i] != "\n" {
            let c = chars[i]

            if inDoubleQuote {
                if c == "\\" {
                    i += 2
                    continue
                }
                if c == "\"" { inDoubleQuote = false }
            } else if inSingleQuote {
                if c == "'" {
                    if i + 1 < chars.count && chars[i + 1] == "'" {
                        i += 2
                        continue
                    }
                    inSingleQuote = false
                }
            } else {
                if c == "\"" { inDoubleQuote = true }
                else if c == "'" { inSingleQuote = true }
                else if c == "[" || c == "{" { depth += 1 }
                else if c == "]" || c == "}" { depth -= 1 }
                else if c == ":" && depth == 0 {
                    let next = i + 1 < chars.count ? chars[i + 1] : nil
                    if next == nil || next == " " || next == "\n" || next == "\t" {
                        return true
                    }
                }
                else if c == "#" {
                    break // rest is comment
                }
            }
            i += 1
        }
        return false
    }

    private func parseBlockMapping(indent: Int) throws -> YAMLValue {
        let map = YAMLMapping()
        let mapIndent = col

        while !atEnd() {
            guard col == mapIndent else { break }
            if isDocumentStart() || isDocumentEnd() { break }

            // Parse key
            let key: YAMLValue
            var isExplicitKey = false
            if let c = peek() {
                if c == "?" && (peekAt(1) == nil || peekAt(1) == " " || peekAt(1) == "\n") {
                    // Explicit key
                    isExplicitKey = true
                    advance() // consume '?'
                    skipInlineWhitespace()
                    if let next = peek(), next == "\n" {
                        advance()
                        skipWhitespaceAndComments()
                        if col > mapIndent {
                            key = try parseBlockNode(minIndent: mapIndent)
                            skipWhitespaceAndComments()
                        } else {
                            key = .null
                        }
                    } else if atEnd() {
                        key = .null
                    } else {
                        key = try parseKeyValue(indent: mapIndent)
                        skipInlineWhitespace()
                    }
                } else if c == "'" {
                    key = try resolveQuotedScalar(parseSingleQuotedScalar())
                } else if c == "\"" {
                    key = try resolveQuotedScalar(parseDoubleQuotedScalar())
                } else if c == "[" {
                    key = try parseFlowSequence()
                } else if c == "{" {
                    key = try parseFlowMapping()
                } else {
                    key = try parseKeyValue(indent: mapIndent)
                }
            } else {
                break
            }

            // Expect ':'
            skipInlineWhitespace()
            // For explicit keys (? syntax), ':' may be on the next line at the same indent
            if isExplicitKey, let nextChar = peek(), nextChar == "\n" {
                let savedPos = pos
                let savedLine = line
                let savedCol = self.col
                advance() // consume newline
                skipWhitespaceAndComments()
                if !(col == mapIndent && peek() == ":") {
                    pos = savedPos
                    line = savedLine
                    self.col = savedCol
                    break
                }
            }
            guard let colon = peek(), colon == ":" else {
                break
            }
            advance() // consume ':'

            // Parse value
            skipInlineWhitespace()
            skipComment()

            let value: YAMLValue
            if atEnd() {
                value = .null
            } else if let next = peek(), next == "\n" {
                advance()
                skipWhitespaceAndComments()
                if atEnd() || col <= mapIndent || isDocumentStart() || isDocumentEnd() {
                    value = .null
                } else {
                    value = try parseBlockNode(minIndent: mapIndent)
                }
            } else if let next = peek(), next == "#" {
                skipComment()
                if let nl = peek(), nl == "\n" { advance() }
                skipWhitespaceAndComments()
                if atEnd() || col <= mapIndent || isDocumentStart() || isDocumentEnd() {
                    value = .null
                } else {
                    value = try parseBlockNode(minIndent: mapIndent)
                }
            } else {
                value = try parseInlineValue(indent: mapIndent)
            }

            map.append(key: key, value: value)

            // Skip to next mapping entry
            skipInlineWhitespace()
            skipComment()
            if let nl = peek(), nl == "\n" { advance() }
            skipWhitespaceAndComments()

            if isDocumentStart() || isDocumentEnd() { break }
        }

        return .mapping(map)
    }

    private func parseBlockMappingWithExplicitKey(indent: Int) throws -> YAMLValue {
        return try parseBlockMapping(indent: indent)
    }

    /// Parse a plain scalar key up to the ':' indicator.
    private func parseKeyValue(indent: Int) throws -> YAMLValue {
        var result = ""
        while !atEnd() {
            let c = peek()!
            if c == ":" {
                let next = peekAt(1)
                if next == nil || next == " " || next == "\n" || next == "\t" {
                    break
                }
            }
            if c == "\n" { break }
            if c == "#" && result.hasSuffix(" ") { break }
            result += String(advance())
        }
        // Trim trailing whitespace
        while result.hasSuffix(" ") || result.hasSuffix("\t") {
            result = String(result.dropLast())
        }
        return resolvePlainScalar(result)
    }

    /// Parse an inline value (on same line as key:).
    private func parseInlineValue(indent: Int) throws -> YAMLValue {
        guard let c = peek() else { return .null }

        if c == "&" { return try parseAnchor(indent: indent, minIndent: indent) }
        if c == "*" { return try parseAlias() }
        if c == "!" { return try parseTag(indent: indent, minIndent: indent) }
        if c == "[" { return try parseFlowSequence() }
        if c == "{" { return try parseFlowMapping() }
        if c == "'" { return try resolveQuotedScalar(parseSingleQuotedScalar()) }
        if c == "\"" { return try resolveQuotedScalar(parseDoubleQuotedScalar()) }
        if c == "|" { return try parseLiteralBlockScalar(indent: indent) }
        if c == ">" { return try parseFoldedBlockScalar(indent: indent) }

        let scalar = try parsePlainScalar(indent: col, minIndent: indent, inFlow: false)
        return resolvePlainScalar(scalar)
    }

    // MARK: - Flow Sequence

    private func parseFlowSequence() throws -> YAMLValue {
        guard let openBracket = peek(), openBracket == "[" else {
            throw error("Expected '['")
        }
        advance() // consume '['

        var items: [YAMLValue] = []
        skipWhitespaceAndComments()

        if let c = peek(), c == "]" {
            advance()
            return .sequence(items)
        }

        while !atEnd() {
            skipWhitespaceAndComments()
            if let c = peek(), c == "]" {
                advance()
                return .sequence(items)
            }

            let value = try parseFlowValue()
            items.append(value)

            skipWhitespaceAndComments()
            if let c = peek(), c == "," {
                advance()
            } else if let c = peek(), c == "]" {
                advance()
                return .sequence(items)
            } else if atEnd() {
                throw error("Unterminated flow sequence")
            }
        }

        throw error("Unterminated flow sequence")
    }

    // MARK: - Flow Mapping

    private func parseFlowMapping() throws -> YAMLValue {
        guard let openBrace = peek(), openBrace == "{" else {
            throw error("Expected '{'")
        }
        advance() // consume '{'

        let map = YAMLMapping()
        skipWhitespaceAndComments()

        if let c = peek(), c == "}" {
            advance()
            return .mapping(map)
        }

        while !atEnd() {
            skipWhitespaceAndComments()
            if let c = peek(), c == "}" {
                advance()
                return .mapping(map)
            }

            // Parse key
            let key: YAMLValue
            if let c = peek() {
                if c == "'" {
                    key = try resolveQuotedScalar(parseSingleQuotedScalar())
                } else if c == "\"" {
                    key = try resolveQuotedScalar(parseDoubleQuotedScalar())
                } else if c == "[" {
                    key = try parseFlowSequence()
                } else if c == "{" {
                    key = try parseFlowMapping()
                } else {
                    key = try parseFlowMappingKey()
                }
            } else {
                throw error("Unexpected end in flow mapping")
            }

            skipWhitespaceAndComments()
            guard let colon = peek(), colon == ":" else {
                throw error("Expected ':' in flow mapping")
            }
            advance() // consume ':'
            skipWhitespaceAndComments()

            // Parse value
            let value: YAMLValue
            if let c = peek(), c == "}" || c == "," {
                value = .null
            } else {
                value = try parseFlowValue()
            }

            map.append(key: key, value: value)

            skipWhitespaceAndComments()
            if let c = peek(), c == "," {
                advance()
            } else if let c = peek(), c == "}" {
                advance()
                return .mapping(map)
            } else if atEnd() {
                throw error("Unterminated flow mapping")
            }
        }

        throw error("Unterminated flow mapping")
    }

    private func parseFlowMappingKey() throws -> YAMLValue {
        var result = ""
        while !atEnd() {
            let c = peek()!
            if c == ":" {
                let next = peekAt(1)
                if next == nil || next == " " || next == "\n" || next == "\t" || next == "," || next == "}" || next == "]" {
                    break
                }
            }
            if c == "," || c == "}" || c == "]" || c == "{" || c == "[" { break }
            if c == "\n" { break }
            if c == "#" && result.hasSuffix(" ") { break }
            result += String(advance())
        }
        while result.hasSuffix(" ") || result.hasSuffix("\t") {
            result = String(result.dropLast())
        }
        return resolvePlainScalar(result)
    }

    private func parseFlowValue() throws -> YAMLValue {
        skipWhitespaceAndComments()
        guard let c = peek() else { return .null }

        if c == "&" { return try parseAnchor(indent: 0, minIndent: -1, inFlow: true) }
        if c == "*" { return try parseAlias() }
        if c == "!" { return try parseTag(indent: 0, minIndent: -1) }
        if c == "[" { return try parseFlowSequence() }
        if c == "{" { return try parseFlowMapping() }
        if c == "'" { return try resolveQuotedScalar(parseSingleQuotedScalar()) }
        if c == "\"" { return try resolveQuotedScalar(parseDoubleQuotedScalar()) }

        // Check for implicit mapping in flow: key: value
        let savedPos = pos
        let savedLine = line
        let savedCol = col
        let scalar = try parsePlainScalar(indent: 0, minIndent: -1, inFlow: true)

        // Check if this is a key in an implicit flow mapping
        skipInlineWhitespace()
        if let next = peek(), next == ":" {
            let afterColon = peekAt(1)
            if afterColon == nil || afterColon == " " || afterColon == "\n" || afterColon == "," || afterColon == "}" || afterColon == "]" || afterColon == "\t" {
                // This is actually a mapping key - restore and parse as mapping
                pos = savedPos
                line = savedLine
                col = savedCol
                return try parseImplicitFlowMapping()
            }
        }

        return resolvePlainScalar(scalar)
    }

    private func parseImplicitFlowMapping() throws -> YAMLValue {
        let map = YAMLMapping()

        while !atEnd() {
            skipWhitespaceAndComments()
            if let c = peek(), c == "}" || c == "]" || c == "," {
                break
            }

            let key: YAMLValue
            if let c = peek() {
                if c == "'" {
                    key = try resolveQuotedScalar(parseSingleQuotedScalar())
                } else if c == "\"" {
                    key = try resolveQuotedScalar(parseDoubleQuotedScalar())
                } else {
                    let keyStr = try parsePlainScalar(indent: 0, minIndent: -1, inFlow: true)
                    key = resolvePlainScalar(keyStr)
                }
            } else {
                break
            }

            skipWhitespaceAndComments()
            guard let colon = peek(), colon == ":" else { break }
            advance()
            skipWhitespaceAndComments()

            let value: YAMLValue
            if let c = peek(), c == "}" || c == "]" || c == "," {
                value = .null
            } else {
                value = try parseFlowValue()
            }

            map.append(key: key, value: value)

            skipWhitespaceAndComments()
            if let c = peek(), c == "," {
                advance()
            } else {
                break
            }
        }

        if map.entries.count == 1 {
            // Single implicit mapping
            return .mapping(map)
        }
        return .mapping(map)
    }

    // MARK: - Plain Scalar

    private func parsePlainScalar(indent: Int, minIndent: Int, inFlow: Bool) throws -> String {
        var result = ""
        var firstLine = true

        while !atEnd() {
            let c = peek()!

            if c == "\n" {
                if inFlow {
                    // In flow context, newlines are folded to spaces
                    advance()
                    skipSpaces()
                    firstLine = false
                    continue
                }

                // In block context, check continuation
                let savedPos = pos
                let savedLine = line
                let savedCol = self.col
                advance() // consume newline

                // Skip empty lines
                var emptyLines = 0
                while let next = peek(), next == "\n" {
                    advance()
                    emptyLines += 1
                }

                skipSpaces()

                // Check if next line continues this scalar
                // Continuation requires indentation greater than the containing structure
                if atEnd() || self.col <= minIndent || isDocumentStart() || isDocumentEnd() {
                    // Scalar ends
                    pos = savedPos
                    line = savedLine
                    self.col = savedCol
                    break
                }

                // Check if next line starts a new structure at same indent level
                if let next = peek() {
                    if next == "-" && isBlockSequenceIndicator() { pos = savedPos; line = savedLine; self.col = savedCol; break }
                    if next == "#" { pos = savedPos; line = savedLine; self.col = savedCol; break }
                    if (next == "&" || next == "*" || next == "!" || next == "|" || next == ">" || next == "[" || next == "]" || next == "{" || next == "}") && self.col <= indent {
                        pos = savedPos; line = savedLine; self.col = savedCol; break
                    }
                    if looksLikeMappingAtCurrentLine(fromCol: self.col) && self.col <= indent {
                        pos = savedPos; line = savedLine; self.col = savedCol; break
                    }
                }

                // Continuation line - fold newlines
                if emptyLines > 0 {
                    for _ in 0..<emptyLines {
                        result += "\n"
                    }
                } else {
                    result += " "
                }
                firstLine = false
                continue
            }

            // End of plain scalar indicators in flow context
            if inFlow && (c == "," || c == "]" || c == "}") {
                break
            }

            // Colon followed by flow indicator or space ends plain scalar
            if c == ":" {
                let next = peekAt(1)
                if next == nil || next == " " || next == "\n" || next == "\t" {
                    if inFlow || firstLine {
                        break
                    }
                }
                if inFlow && (next == "," || next == "]" || next == "}") {
                    break
                }
            }

            // Comment after space
            if c == "#" && result.hasSuffix(" ") {
                // Remove trailing space
                while result.hasSuffix(" ") {
                    result = String(result.dropLast())
                }
                break
            }

            result += String(advance())
        }

        // Trim trailing whitespace
        while result.hasSuffix(" ") || result.hasSuffix("\t") {
            result = String(result.dropLast())
        }

        return result
    }

    // MARK: - Single-Quoted Scalar

    private func parseSingleQuotedScalar() throws -> String {
        guard let openQuote = peek(), openQuote == "'" else {
            throw error("Expected single quote")
        }
        advance() // consume opening quote

        var result = ""
        while !atEnd() {
            let c = peek()!

            if c == "'" {
                advance()
                // Check for escaped quote ('')
                if let next = peek(), next == "'" {
                    result += "'"
                    advance()
                } else {
                    return result
                }
            } else if c == "\n" {
                advance()
                // Fold newlines
                var emptyLines = 0
                while let next = peek(), next == "\n" {
                    advance()
                    emptyLines += 1
                }
                skipSpaces()
                if emptyLines > 0 {
                    for _ in 0..<emptyLines {
                        result += "\n"
                    }
                } else {
                    result += " "
                }
            } else {
                result += String(advance())
            }
        }

        throw error("Unterminated single-quoted scalar")
    }

    // MARK: - Double-Quoted Scalar

    private func parseDoubleQuotedScalar() throws -> String {
        guard let openQuote = peek(), openQuote == "\"" else {
            throw error("Expected double quote")
        }
        advance() // consume opening quote

        var result = ""
        while !atEnd() {
            let c = peek()!

            if c == "\"" {
                advance()
                return result
            } else if c == "\\" {
                advance() // consume backslash
                guard !atEnd() else {
                    throw error("Unterminated escape sequence")
                }
                let esc = advance()
                switch esc {
                case "0": result += "\u{0000}"
                case "a": result += "\u{0007}"
                case "b": result += "\u{0008}"
                case "t", "\t": result += "\t"
                case "n": result += "\n"
                case "v": result += "\u{000B}"
                case "f": result += "\u{000C}"
                case "r": result += "\r"
                case "e": result += "\u{001B}"
                case " ": result += " "
                case "\"": result += "\""
                case "/": result += "/"
                case "\\": result += "\\"
                case "N": result += "\u{0085}"
                case "_": result += "\u{00A0}"
                case "L": result += "\u{2028}"
                case "P": result += "\u{2029}"
                case "x":
                    let hex = try readHexChars(2)
                    result += hex
                case "u":
                    let hex = try readHexChars(4)
                    result += hex
                case "U":
                    let hex = try readHexChars(8)
                    result += hex
                case "\n":
                    // Escaped newline - skip whitespace on next line
                    while let next = peek(), next == " " || next == "\t" || next == "\n" {
                        advance()
                    }
                default:
                    result += "\\"
                    result += String(esc)
                }
            } else if c == "\n" {
                advance()
                // Fold newlines
                var emptyLines = 0
                while let next = peek(), next == "\n" {
                    advance()
                    emptyLines += 1
                }
                skipSpaces()
                if emptyLines > 0 {
                    for _ in 0..<emptyLines {
                        result += "\n"
                    }
                } else {
                    result += " "
                }
            } else {
                result += String(advance())
            }
        }

        throw error("Unterminated double-quoted scalar")
    }

    private func hexDigitValue(_ ch: Character) -> Int {
        switch ch {
        case "0": return 0; case "1": return 1; case "2": return 2; case "3": return 3
        case "4": return 4; case "5": return 5; case "6": return 6; case "7": return 7
        case "8": return 8; case "9": return 9
        case "a", "A": return 10; case "b", "B": return 11
        case "c", "C": return 12; case "d", "D": return 13
        case "e", "E": return 14; case "f", "F": return 15
        default: return -1
        }
    }

    private func readHexChars(_ count: Int) throws -> String {
        var codePoint = 0
        for _ in 0..<count {
            guard !atEnd() else {
                throw error("Unexpected end in hex escape")
            }
            let ch = advance()
            let digit = hexDigitValue(ch)
            guard digit >= 0 else {
                throw error("Invalid hex digit in escape sequence")
            }
            codePoint = codePoint * 16 + digit
        }
        #if !SKIP
        guard let scalar = Unicode.Scalar(UInt32(codePoint)) else {
            throw error("Invalid Unicode code point")
        }
        return String(Character(scalar))
        #else
        // SKIP INSERT: return String(codePoint.toChar())
        return ""
        #endif
    }

    // MARK: - Literal Block Scalar (|)

    private func parseLiteralBlockScalar(indent: Int) throws -> YAMLValue {
        advance() // consume '|'
        let (chomping, explicitIndent) = try parseBlockScalarHeader()
        let content = try parseBlockScalarContent(indent: indent, explicitIndent: explicitIndent, chomping: chomping, fold: false)
        return .string(content)
    }

    // MARK: - Folded Block Scalar (>)

    private func parseFoldedBlockScalar(indent: Int) throws -> YAMLValue {
        advance() // consume '>'
        let (chomping, explicitIndent) = try parseBlockScalarHeader()
        let content = try parseBlockScalarContent(indent: indent, explicitIndent: explicitIndent, chomping: chomping, fold: true)
        return .string(content)
    }

    private enum Chomping {
        case strip  // -
        case clip   // default
        case keep   // +
    }

    private func parseBlockScalarHeader() throws -> (Chomping, Int?) {
        var chomping = Chomping.clip
        var explicitIndent: Int? = nil

        // Parse indicators
        while let c = peek(), c != "\n" && c != "#" {
            if c == "-" {
                chomping = .strip
                advance()
            } else if c == "+" {
                chomping = .keep
                advance()
            } else if c >= "1" && c <= "9" {
                let digitValue = Int(String(c))!
                explicitIndent = digitValue
                advance()
            } else if c == " " || c == "\t" {
                advance()
            } else {
                throw error("Unexpected character '\(c)' in block scalar header")
            }
        }

        // Skip comment
        skipComment()

        // Consume newline
        if let c = peek(), c == "\n" {
            advance()
        }

        return (chomping, explicitIndent)
    }

    private func parseBlockScalarContent(indent: Int, explicitIndent: Int?, chomping: Chomping, fold: Bool) throws -> String {
        // Determine content indentation from explicit indicator or first non-empty line
        var contentIndent: Int
        if let ei = explicitIndent {
            contentIndent = indent + ei
        } else {
            // Find indentation of first non-empty content line
            let savedPos = pos
            let savedLine = line
            let savedCol = col
            contentIndent = -1

            while !atEnd() {
                // Skip spaces at start of line
                var lineIndent = 0
                while let c = peek(), c == " " {
                    advance()
                    lineIndent += 1
                }

                if let c = peek(), c == "\n" {
                    advance()
                    continue
                }

                if atEnd() {
                    break
                }

                contentIndent = lineIndent
                break
            }

            pos = savedPos
            line = savedLine
            col = savedCol

            if contentIndent <= indent {
                contentIndent = indent + 1
            }
        }

        var lines: [String] = []
        var trailingNewlines = 0

        while !atEnd() {
            // Count spaces at start of line
            var lineIndent = 0
            while let c = peek(), c == " " {
                advance()
                lineIndent += 1
            }

            // Empty line
            if let c = peek(), c == "\n" {
                advance()
                trailingNewlines += 1
                // Add empty lines to content
                lines.append("")
                continue
            }

            // End of input with no content
            if atEnd() {
                if lineIndent < contentIndent {
                    // Not part of block
                    break
                }
                break
            }

            // Check if line is less indented (end of block)
            if lineIndent < contentIndent {
                // Restore position to start of this line
                pos -= lineIndent
                col -= lineIndent
                break
            }

            trailingNewlines = 0

            // Read rest of line
            var lineContent = ""
            // Include extra indentation
            if lineIndent > contentIndent {
                for _ in 0..<(lineIndent - contentIndent) {
                    lineContent += " "
                }
            }

            while !atEnd() {
                let c = peek()!
                if c == "\n" {
                    advance()
                    break
                }
                lineContent += String(advance())
            }

            lines.append(lineContent)
        }

        // Build result
        if fold {
            return buildFoldedContent(lines: lines, chomping: chomping, contentIndent: contentIndent)
        } else {
            return buildLiteralContent(lines: lines, chomping: chomping)
        }
    }

    private func buildLiteralContent(lines: [String], chomping: Chomping) -> String {
        if lines.isEmpty {
            return chomping == .keep ? "\n" : ""
        }

        // Find last non-empty line
        var lastNonEmpty = lines.count - 1
        while lastNonEmpty >= 0 && lines[lastNonEmpty].isEmpty {
            lastNonEmpty -= 1
        }

        if lastNonEmpty < 0 {
            // All empty lines
            switch chomping {
            case .strip: return ""
            case .clip: return ""
            case .keep:
                var result = ""
                for _ in lines {
                    result += "\n"
                }
                return result
            }
        }

        var result = ""
        for i in 0...lastNonEmpty {
            if i > 0 { result += "\n" }
            result += lines[i]
        }

        // Apply chomping
        switch chomping {
        case .strip:
            break // no trailing newline
        case .clip:
            result += "\n"
        case .keep:
            result += "\n"
            for _ in (lastNonEmpty + 1)..<lines.count {
                result += "\n"
            }
        }

        return result
    }

    private func buildFoldedContent(lines: [String], chomping: Chomping, contentIndent: Int) -> String {
        if lines.isEmpty {
            return chomping == .keep ? "\n" : ""
        }

        var lastNonEmpty = lines.count - 1
        while lastNonEmpty >= 0 && lines[lastNonEmpty].isEmpty {
            lastNonEmpty -= 1
        }

        if lastNonEmpty < 0 {
            switch chomping {
            case .strip: return ""
            case .clip: return ""
            case .keep:
                var result = ""
                for _ in lines {
                    result += "\n"
                }
                return result
            }
        }

        var result = ""
        var prevWasMore = false // "more-indented" line
        var prevWasEmpty = false

        for i in 0...lastNonEmpty {
            let ln = lines[i]

            if ln.isEmpty {
                result += "\n"
                prevWasEmpty = true
                // Don't reset prevWasMore: the preserved break after a more-indented
                // section must be maintained through empty lines so that transitioning
                // back to a normal line produces the correct number of newlines.
                continue
            }

            let isMoreIndented = ln.hasPrefix(" ")

            if i == 0 {
                result += ln
            } else if isMoreIndented || prevWasMore {
                result += "\n"
                result += ln
            } else if prevWasEmpty {
                result += ln
            } else {
                result += " "
                result += ln
            }

            prevWasMore = isMoreIndented
            prevWasEmpty = false
        }

        // Apply chomping
        switch chomping {
        case .strip:
            break
        case .clip:
            result += "\n"
        case .keep:
            result += "\n"
            for _ in (lastNonEmpty + 1)..<lines.count {
                result += "\n"
            }
        }

        return result
    }

    // MARK: - Anchors and Aliases

    private func parseAnchor(indent: Int, minIndent: Int, inFlow: Bool = false) throws -> YAMLValue {
        advance() // consume '&'
        var name = ""
        while let c = peek(), c != " " && c != "\n" && c != "\t" && c != "," && c != "]" && c != "}" && c != ":" {
            name += String(advance())
        }
        guard !name.isEmpty else {
            throw error("Empty anchor name")
        }

        skipInlineWhitespace()

        let value: YAMLValue
        if atEnd() || peek() == "\n" {
            if let nl = peek(), nl == "\n" {
                advance()
            }
            skipWhitespaceAndComments()
            if atEnd() || col <= minIndent {
                value = .null
            } else {
                value = try parseBlockNode(minIndent: minIndent)
            }
        } else if inFlow {
            value = try parseFlowValue()
        } else {
            value = try parseNodeAtCurrentPosition(indent: col, minIndent: minIndent)
        }

        anchors[name] = value
        return value
    }

    private func parseAlias() throws -> YAMLValue {
        advance() // consume '*'
        var name = ""
        while let c = peek(), c != " " && c != "\n" && c != "\t" && c != "," && c != "]" && c != "}" && c != ":" {
            name += String(advance())
        }
        guard !name.isEmpty else {
            throw error("Empty alias name")
        }
        guard let value = anchors[name] else {
            throw error("Undefined alias '\(name)'")
        }
        return value
    }

    // MARK: - Tags

    private func parseTag(indent: Int, minIndent: Int) throws -> YAMLValue {
        advance() // consume first '!'
        var tag = "!"

        if let c = peek(), c == "!" {
            // Secondary tag handle !!
            tag += String(advance())
            while let c = peek(), c != " " && c != "\n" && c != "\t" {
                tag += String(advance())
            }
        } else if let c = peek(), c != " " && c != "\n" {
            while let c = peek(), c != " " && c != "\n" && c != "\t" {
                tag += String(advance())
            }
        }

        skipInlineWhitespace()

        // Parse the tagged value
        let value: YAMLValue
        if atEnd() || peek() == "\n" {
            if let nl = peek(), nl == "\n" { advance() }
            skipWhitespaceAndComments()
            if atEnd() || col <= indent {
                value = .null
            } else {
                value = try parseBlockNode(minIndent: minIndent)
            }
        } else {
            value = try parseNodeAtCurrentPosition(indent: col, minIndent: minIndent)
        }

        // Apply tag
        return applyTag(tag, to: value)
    }

    private func applyTag(_ tag: String, to value: YAMLValue) -> YAMLValue {
        switch tag {
        case "!!null":
            return .null
        case "!!bool":
            if case .string(let s) = value {
                let lower = s.lowercased()
                if lower == "true" || lower == "yes" || lower == "on" { return .bool(true) }
                if lower == "false" || lower == "no" || lower == "off" { return .bool(false) }
            }
            if case .bool(let b) = value { return .bool(b) }
            return value
        case "!!int":
            if case .string(let s) = value {
                if let v = Int(s) { return .int(v) }
            }
            return value
        case "!!float":
            if case .string(let s) = value {
                if let v = Double(s) { return .double(v) }
                let lower = s.lowercased()
                if lower == ".inf" || lower == "+.inf" { return .double(Double.infinity) }
                if lower == "-.inf" { return .double(-Double.infinity) }
                if lower == ".nan" { return .double(Double.nan) }
            }
            return value
        case "!!str":
            // Force to string
            switch value {
            case .string: return value
            case .bool(let b): return .string(b ? "true" : "false")
            case .int(let i): return .string("\(i)")
            case .double(let d): return .string("\(d)")
            case .null: return .string("")
            default: return value
            }
        case "!!seq":
            return value
        case "!!map":
            return value
        default:
            // Unknown tags are ignored, return the value as-is
            return value
        }
    }

    // MARK: - Scalar Resolution

    private func resolvePlainScalar(_ value: String) -> YAMLValue {
        if value.isEmpty { return .null }

        // Null
        if value == "null" || value == "Null" || value == "NULL" || value == "~" {
            return .null
        }

        // Boolean (YAML 1.2 core schema)
        if value == "true" || value == "True" || value == "TRUE" {
            return .bool(true)
        }
        if value == "false" || value == "False" || value == "FALSE" {
            return .bool(false)
        }

        // Integer
        if let intVal = parseInteger(value) {
            return .int(intVal)
        }

        // Float
        if let doubleVal = parseFloat(value) {
            return .double(doubleVal)
        }

        return .string(value)
    }

    private func resolveQuotedScalar(_ value: String) -> YAMLValue {
        return .string(value)
    }

    private func parseInteger(_ s: String) -> Int? {
        if s.isEmpty { return nil }

        var str = s
        var negative = false

        if str.hasPrefix("-") {
            negative = true
            str = String(str.dropFirst())
        } else if str.hasPrefix("+") {
            str = String(str.dropFirst())
        }

        if str.isEmpty { return nil }

        // Octal
        if str.hasPrefix("0o") {
            let octStr = String(str.dropFirst(2))
            guard !octStr.isEmpty else { return nil }
            if let v = parseOctalString(octStr) {
                return negative ? -v : v
            }
            return nil
        }

        // Hex
        if str.hasPrefix("0x") {
            let hexStr = String(str.dropFirst(2))
            guard !hexStr.isEmpty else { return nil }
            if let v = parseHexString(hexStr) {
                return negative ? -v : v
            }
            return nil
        }

        // Decimal - must be all digits (possibly with underscores)
        let cleaned = str.replacingOccurrences(of: "_", with: "")
        if cleaned.isEmpty { return nil }

        // YAML 1.2: decimal integers must not have leading zeros (except "0" itself)
        if cleaned.count > 1 && cleaned.hasPrefix("0") { return nil }

        // Verify all characters are digits
        for ch in cleaned {
            if ch < "0" || ch > "9" { return nil }
        }

        if let v = Int(cleaned) {
            return negative ? -v : v
        }

        return nil
    }

    private func parseOctalString(_ s: String) -> Int? {
        var result = 0
        for ch in s {
            guard ch >= "0" && ch <= "7" else { return nil }
            let d = hexDigitValue(ch)
            result = result * 8 + d
        }
        return result
    }

    private func parseHexString(_ s: String) -> Int? {
        var result = 0
        for ch in s {
            let d = hexDigitValue(ch)
            guard d >= 0 else { return nil }
            result = result * 16 + d
        }
        return result
    }

    private func parseFloat(_ s: String) -> Double? {
        if s.isEmpty { return nil }

        // Special values
        let lower = s.lowercased()
        if lower == ".inf" || lower == "+.inf" { return Double.infinity }
        if lower == "-.inf" { return -Double.infinity }
        if lower == ".nan" { return Double.nan }

        var str = s
        var negative = false

        if str.hasPrefix("-") {
            negative = true
            str = String(str.dropFirst())
        } else if str.hasPrefix("+") {
            str = String(str.dropFirst())
        }

        let cleaned = str.replacingOccurrences(of: "_", with: "")
        if cleaned.isEmpty { return nil }

        // Must contain a dot or exponent to be a float
        if !cleaned.contains(".") && !cleaned.contains("e") && !cleaned.contains("E") {
            return nil
        }

        // Verify format: digits, dots, e/E, +/-
        for ch in cleaned {
            if (ch < "0" || ch > "9") && ch != "." && ch != "e" && ch != "E" && ch != "+" && ch != "-" {
                return nil
            }
        }

        if let v = Double(cleaned) {
            return negative ? -v : v
        }

        return nil
    }
}
