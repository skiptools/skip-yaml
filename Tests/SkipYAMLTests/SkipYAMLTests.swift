// Copyright 2024-2026 Skip
// SPDX-License-Identifier: MPL-2.0

import Testing
import Foundation
@testable import SkipYAML

@Suite struct SkipYAMLTests {

    // MARK: - Basic Scalar Parsing

    @Test func testNull() throws {
        #expect(try YAMLValue.parse("null") == .null)
        #expect(try YAMLValue.parse("~") == .null)
        #expect(try YAMLValue.parse("Null") == .null)
        #expect(try YAMLValue.parse("NULL") == .null)
        #expect(try YAMLValue.parse("") == .null)
    }

    @Test func testBooleans() throws {
        #expect(try YAMLValue.parse("true") == .bool(true))
        #expect(try YAMLValue.parse("True") == .bool(true))
        #expect(try YAMLValue.parse("TRUE") == .bool(true))
        #expect(try YAMLValue.parse("false") == .bool(false))
        #expect(try YAMLValue.parse("False") == .bool(false))
        #expect(try YAMLValue.parse("FALSE") == .bool(false))
    }

    @Test func testIntegers() throws {
        #expect(try YAMLValue.parse("0") == .int(0))
        #expect(try YAMLValue.parse("42") == .int(42))
        #expect(try YAMLValue.parse("-17") == .int(-17))
        #expect(try YAMLValue.parse("+99") == .int(99))
        #expect(try YAMLValue.parse("0x1A") == .int(26))
        #expect(try YAMLValue.parse("0o17") == .int(15))
        #expect(try YAMLValue.parse("1_000") == .int(1000))
    }

    @Test func testFloats() throws {
        #expect(try YAMLValue.parse("1.0") == .double(1.0))
        #expect(try YAMLValue.parse("3.14") == .double(3.14))
        #expect(try YAMLValue.parse("-0.5") == .double(-0.5))
        #expect(try YAMLValue.parse("1.0e3") == .double(1000.0))
        #expect(try YAMLValue.parse("2.5E-1") == .double(0.25))

        let inf = try YAMLValue.parse(".inf")
        if case .double(let v) = inf { #expect(v == Double.infinity) }
        else { throw YAMLError.parseError("Expected .double(.inf)") }

        let negInf = try YAMLValue.parse("-.inf")
        if case .double(let v) = negInf { #expect(v == -Double.infinity) }
        else { throw YAMLError.parseError("Expected .double(-.inf)") }

        let nan = try YAMLValue.parse(".nan")
        if case .double(let v) = nan { #expect(v.isNaN) }
        else { throw YAMLError.parseError("Expected .double(.nan)") }
    }

    @Test func testPlainStrings() throws {
        #expect(try YAMLValue.parse("hello") == .string("hello"))
        #expect(try YAMLValue.parse("hello world") == .string("hello world"))
    }

    // MARK: - Quoted Scalars

    @Test func testSingleQuoted() throws {
        #expect(try YAMLValue.parse("'hello'") == .string("hello"))
        #expect(try YAMLValue.parse("'it''s'") == .string("it's"))
        #expect(try YAMLValue.parse("''") == .string(""))
        #expect(try YAMLValue.parse("'true'") == .string("true"))
        #expect(try YAMLValue.parse("'42'") == .string("42"))
        #expect(try YAMLValue.parse("'null'") == .string("null"))
    }

    @Test func testDoubleQuoted() throws {
        #expect(try YAMLValue.parse("\"hello\"") == .string("hello"))
        #expect(try YAMLValue.parse("\"hello\\nworld\"") == .string("hello\nworld"))
        #expect(try YAMLValue.parse("\"tab\\there\"") == .string("tab\there"))
        #expect(try YAMLValue.parse("\"escaped\\\"quote\"") == .string("escaped\"quote"))
        #expect(try YAMLValue.parse("\"backslash\\\\end\"") == .string("backslash\\end"))
        #expect(try YAMLValue.parse("\"null\\0char\"") == .string("null\u{0000}char"))
        #expect(try YAMLValue.parse("\"unicode\\u0041\"") == .string("unicodeA"))
        #expect(try YAMLValue.parse("\"\"") == .string(""))
    }

    // MARK: - Block Sequences

    @Test func testSimpleSequence() throws {
        let yaml = """
        - one
        - two
        - three
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result == .sequence([.string("one"), .string("two"), .string("three")]))
    }

    @Test func testSequenceWithTypes() throws {
        let yaml = """
        - hello
        - 42
        - true
        - 3.14
        - null
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result == .sequence([.string("hello"), .int(42), .bool(true), .double(3.14), .null]))
    }

    @Test func testNestedSequences() throws {
        let yaml = """
        - - a
          - b
        - - c
          - d
        """
        let result = try YAMLValue.parse(yaml)
        let expected: YAMLValue = .sequence([
            .sequence([.string("a"), .string("b")]),
            .sequence([.string("c"), .string("d")])
        ])
        #expect(result == expected)
    }

    // MARK: - Block Mappings

    @Test func testSimpleMapping() throws {
        let yaml = """
        name: John
        age: 30
        active: true
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["name"] == .string("John"))
        #expect(result["age"] == .int(30))
        #expect(result["active"] == .bool(true))
    }

    @Test func testNestedMapping() throws {
        let yaml = """
        person:
          name: John
          address:
            city: NYC
            zip: 10001
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["person"]?["name"] == .string("John"))
        #expect(result["person"]?["address"]?["city"] == .string("NYC"))
        #expect(result["person"]?["address"]?["zip"] == .int(10001))
    }

    @Test func testMappingWithSequenceValues() throws {
        let yaml = """
        fruits:
          - apple
          - banana
          - cherry
        colors:
          - red
          - blue
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["fruits"] == .sequence([.string("apple"), .string("banana"), .string("cherry")]))
        #expect(result["colors"] == .sequence([.string("red"), .string("blue")]))
    }

    @Test func testSequenceOfMappings() throws {
        let yaml = """
        - name: Alice
          age: 25
        - name: Bob
          age: 30
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result[0]?["name"] == .string("Alice"))
        #expect(result[0]?["age"] == .int(25))
        #expect(result[1]?["name"] == .string("Bob"))
        #expect(result[1]?["age"] == .int(30))
    }

    // MARK: - Flow Collections

    @Test func testFlowSequence() throws {
        #expect(try YAMLValue.parse("[1, 2, 3]") == .sequence([.int(1), .int(2), .int(3)]))
        #expect(try YAMLValue.parse("[]") == .sequence([]))
        #expect(try YAMLValue.parse("[hello, world]") == .sequence([.string("hello"), .string("world")]))
        #expect(try YAMLValue.parse("[true, false, null]") == .sequence([.bool(true), .bool(false), .null]))
    }

    @Test func testFlowMapping() throws {
        let result = try YAMLValue.parse("{a: 1, b: 2}")
        #expect(result["a"] == .int(1))
        #expect(result["b"] == .int(2))

        let empty = try YAMLValue.parse("{}")
        #expect(empty == .mapping(YAMLMapping()))
    }

    @Test func testNestedFlow() throws {
        let result = try YAMLValue.parse("{a: [1, 2], b: {c: 3}}")
        #expect(result["a"] == .sequence([.int(1), .int(2)]))
        #expect(result["b"]?["c"] == .int(3))
    }

    @Test func testFlowInBlock() throws {
        let yaml = """
        items: [1, 2, 3]
        config: {debug: true, level: 5}
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["items"] == .sequence([.int(1), .int(2), .int(3)]))
        #expect(result["config"]?["debug"] == .bool(true))
        #expect(result["config"]?["level"] == .int(5))
    }

    // MARK: - Block Scalars

    @Test func testLiteralBlock() throws {
        let yaml = """
        content: |
          line one
          line two
          line three
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["content"] == .string("line one\nline two\nline three\n"))
    }

    @Test func testLiteralBlockStrip() throws {
        let yaml = """
        content: |-
          line one
          line two
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["content"] == .string("line one\nline two"))
    }

    @Test func testLiteralBlockKeep() throws {
        let yaml = """
        content: |+
          line one
          line two

        """ + "\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["content"] == .string("line one\nline two\n\n"))
    }

    @Test func testFoldedBlock() throws {
        let yaml = """
        content: >
          this is a
          long paragraph
          of text
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["content"] == .string("this is a long paragraph of text\n"))
    }

    @Test func testFoldedBlockStrip() throws {
        let yaml = """
        content: >-
          this is
          folded
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["content"] == .string("this is folded"))
    }

    // MARK: - Comments

    @Test func testComments() throws {
        let yaml = """
        # This is a comment
        name: John # inline comment
        age: 30
        # Another comment
        city: NYC
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["name"] == .string("John"))
        #expect(result["age"] == .int(30))
        #expect(result["city"] == .string("NYC"))
    }

    // MARK: - Multi-Document

    @Test func testMultiDocument() throws {
        let yaml = """
        ---
        first
        ---
        second
        ---
        third
        """
        let docs = try YAMLValue.parseAll(yaml)
        #expect(docs.count == 3)
        #expect(docs[0] == .string("first"))
        #expect(docs[1] == .string("second"))
        #expect(docs[2] == .string("third"))
    }

    @Test func testDocumentEnd() throws {
        let yaml = """
        ---
        hello
        ...
        """
        let docs = try YAMLValue.parseAll(yaml)
        #expect(docs.count == 1)
        #expect(docs[0] == .string("hello"))
    }

    // MARK: - Anchors and Aliases

    @Test func testSimpleAnchorAlias() throws {
        let yaml = """
        - &anchor hello
        - *anchor
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result[0] == .string("hello"))
        #expect(result[1] == .string("hello"))
    }

    // MARK: - Tags

    @Test func testStringTag() throws {
        let yaml = "!!str 42"
        let result = try YAMLValue.parse(yaml)
        #expect(result == .string("42"))
    }

    @Test func testNullTag() throws {
        let yaml = "!!null ''"
        let result = try YAMLValue.parse(yaml)
        #expect(result == .null)
    }

    // MARK: - Value Access

    @Test func testSubscript() throws {
        let yaml = """
        items:
          - first
          - second
        config:
          debug: true
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["items"]?[0] == .string("first"))
        #expect(result["items"]?[1] == .string("second"))
        #expect(result["config"]?["debug"] == .bool(true))
        #expect(result["nonexistent"] == nil)
        #expect(result["items"]?[99] == nil)
    }

    @Test func testValueAccessors() throws {
        #expect(YAMLValue.string("hello").stringValue == "hello")
        #expect(YAMLValue.int(42).intValue == 42)
        #expect(YAMLValue.double(3.14).doubleValue == 3.14)
        #expect(YAMLValue.bool(true).boolValue == true)
        #expect(YAMLValue.null.isNull == true)
        #expect(YAMLValue.string("hello").isScalar == true)
        #expect(YAMLValue.sequence([]).isCollection == true)
    }

    // MARK: - Emitter

    @Test func testEmitNull() throws {
        let yaml = YAMLValue.null.yamlString()
        #expect(yaml == "null\n")
    }

    @Test func testEmitScalars() throws {
        #expect(YAMLValue.bool(true).yamlString() == "true\n")
        #expect(YAMLValue.int(42).yamlString() == "42\n")
        #expect(YAMLValue.double(3.14).yamlString() == "3.14\n")
        #expect(YAMLValue.string("hello").yamlString() == "hello\n")
    }

    @Test func testEmitMapping() throws {
        let map = YAMLMapping()
        map.append(key: .string("name"), value: .string("John"))
        map.append(key: .string("age"), value: .int(30))
        let yaml = YAMLValue.mapping(map).yamlString()
        #expect(yaml.contains("name: John"))
        #expect(yaml.contains("age: 30"))
    }

    @Test func testEmitSequence() throws {
        let yaml = YAMLValue.sequence([.int(1), .int(2), .int(3)]).yamlString()
        #expect(yaml.contains("- 1"))
        #expect(yaml.contains("- 2"))
        #expect(yaml.contains("- 3"))
    }

    @Test func testEmitQuotedStrings() throws {
        let emptyYaml = YAMLValue.string("").yamlString()
        #expect(emptyYaml.contains("''"))
        let trueYaml = YAMLValue.string("true").yamlString()
        #expect(trueYaml.contains("\"true\"") || trueYaml.contains("'true'"))
    }

    @Test func testEmitSpecialFloats() throws {
        let infYaml = YAMLValue.double(Double.infinity).yamlString()
        #expect(infYaml.contains(".inf"))

        let nanYaml = YAMLValue.double(Double.nan).yamlString()
        #expect(nanYaml.contains(".nan"))
    }

    // MARK: - Edge Cases

    @Test func testEmptyMapping() throws {
        let result = try YAMLValue.parse("{}")
        #expect(result == .mapping(YAMLMapping()))
    }

    @Test func testEmptySequence() throws {
        let result = try YAMLValue.parse("[]")
        #expect(result == .sequence([]))
    }

    @Test func testColonInValue() throws {
        let yaml = "time: 12:30:00"
        let result = try YAMLValue.parse(yaml)
        #expect(result["time"] == .string("12:30:00"))
    }

    @Test func testQuotedKeys() throws {
        let yaml = """
        "key with spaces": value
        'another key': 42
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["key with spaces"] == .string("value"))
        #expect(result["another key"] == .int(42))
    }

    @Test func testEmptyValues() throws {
        let yaml = """
        key1:
        key2:
        key3: value
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["key1"] == .null)
        #expect(result["key2"] == .null)
        #expect(result["key3"] == .string("value"))
    }

    @Test func testComplexNesting() throws {
        let yaml = """
        database:
          host: localhost
          port: 5432
          credentials:
            user: admin
            pass: secret
          replicas:
            - host: replica1
              port: 5433
            - host: replica2
              port: 5434
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["database"]?["host"] == .string("localhost"))
        #expect(result["database"]?["port"] == .int(5432))
        #expect(result["database"]?["credentials"]?["user"] == .string("admin"))
        #expect(result["database"]?["replicas"]?[0]?["host"] == .string("replica1"))
        #expect(result["database"]?["replicas"]?[1]?["port"] == .int(5434))
    }

    @Test func testMultilineString() throws {
        let yaml = """
        description: |
          This is a multi-line
          string that preserves
          newlines exactly.
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["description"] == .string("This is a multi-line\nstring that preserves\nnewlines exactly.\n"))
    }

    @Test func testFoldedMultiline() throws {
        let yaml = """
        description: >
          This is a long
          paragraph that gets
          folded into one line.
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["description"] == .string("This is a long paragraph that gets folded into one line.\n"))
    }

    // MARK: - YAML Test Suite Fixtures

    @Test func testYTS_229Q() throws {
        let yaml = """
        -
          name: Mark McGwire
          hr: 65
          avg: 0.278
        -
          name: Sammy Sosa
          hr: 63
          avg: 0.288
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result[0]?["name"] == .string("Mark McGwire"))
        #expect(result[0]?["hr"] == .int(65))
        #expect(result[1]?["name"] == .string("Sammy Sosa"))
    }

    @Test func testYTS_2AUY() throws {
        let yaml = """
        american:
          - Boston Red Sox
          - Detroit Tigers
          - New York Yankees
        national:
          - New York Mets
          - Chicago Cubs
          - Atlanta Braves
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["american"]?[0] == .string("Boston Red Sox"))
        #expect(result["national"]?[2] == .string("Atlanta Braves"))
    }

    @Test func testYTS_27NA() throws {
        let yaml = """
        - [name, hr, avg]
        - [Mark McGwire, 65, 0.278]
        - [Sammy Sosa, 63, 0.288]
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result[0] == .sequence([.string("name"), .string("hr"), .string("avg")]))
        #expect(result[1]?[0] == .string("Mark McGwire"))
    }

    @Test func testYTS_2LFX() throws {
        let yaml = """
        Mark McGwire: {hr: 65, avg: 0.278}
        Sammy Sosa: {hr: 63, avg: 0.288}
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["Mark McGwire"]?["hr"] == .int(65))
        #expect(result["Sammy Sosa"]?["avg"] == .double(0.288))
    }

    @Test func testYTS_6FWR() throws {
        let yaml = "[foo, bar, baz]"
        let result = try YAMLValue.parse(yaml)
        #expect(result == .sequence([.string("foo"), .string("bar"), .string("baz")]))
    }

    @Test func testYTS_6JQW() throws {
        let yaml = """
        ---
        # Products purchased
        - item    : Super Hoop
          quantity: 1
        - item    : Basketball
          quantity: 4
        - item    : Big Shoes
          quantity: 1
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result[0]?["item"] == .string("Super Hoop"))
        #expect(result[1]?["quantity"] == .int(4))
        #expect(result[2]?["item"] == .string("Big Shoes"))
    }

    @Test func testYTS_6SLA() throws {
        // Uses regular string because \\n (YAML escape) requires Swift escape processing
        // which differs from Kotlin raw strings
        let yaml = "plain: This unquoted scalar spans many lines.\nquoted: \"So does this quoted scalar.\\n\"\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["plain"] == .string("This unquoted scalar spans many lines."))
        #expect(result["quoted"] == .string("So does this quoted scalar.\n"))
    }

    @Test func testYTS_6WLZ() throws {
        let yaml = """
        ---
        hr: # 1998 hr ranking
          - Mark McGwire
          - Sammy Sosa
        rbi:
          # 1998 rbi ranking
          - Sammy Sosa
          - Ken Griffey
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["hr"]?[0] == .string("Mark McGwire"))
        #expect(result["rbi"]?[1] == .string("Ken Griffey"))
    }

    @Test func testYTS_9WXW() throws {
        let yaml = """
        - foo:   bar
        - - baz
          - baz
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result[0]?["foo"] == .string("bar"))
        #expect(result[1] == .sequence([.string("baz"), .string("baz")]))
    }

    @Test func testYTS_J3BT() throws {
        let yaml = """
        ---
        hr:
          - Mark McGwire
          # Following node labeled SS
          - &SS Sammy Sosa
        rbi:
          - *SS # Preceding node labeled SS
          - Ken Griffey
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["hr"]?[1] == .string("Sammy Sosa"))
        #expect(result["rbi"]?[0] == .string("Sammy Sosa"))
    }

    @Test func testYTS_M7A3() throws {
        let yaml = """
        ---
        - val1
        - val2
        ---
        - val3
        """
        let docs = try YAMLValue.parseAll(yaml)
        #expect(docs.count == 2)
        #expect(docs[0] == .sequence([.string("val1"), .string("val2")]))
        #expect(docs[1] == .sequence([.string("val3")]))
    }

    @Test func testYTS_UT92() throws {
        let yaml = """
        hr:  65
        avg: 0.278
        rbi: 147
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["hr"] == .int(65))
        #expect(result["avg"] == .double(0.278))
        #expect(result["rbi"] == .int(147))
    }

    @Test func testYTS_W42U() throws {
        let yaml = """
        - # Empty
        - |
          block node
        - - one # Compact
          - two # sequence
        - one: two # Compact mapping
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result[0] == .null)
        #expect(result[1] == .string("block node\n"))
        #expect(result[2] == .sequence([.string("one"), .string("two")]))
        #expect(result[3]?["one"] == .string("two"))
    }

    @Test func testYTS_ZF4X() throws {
        let yaml = """
        # Ranking of 1998 home runs
        ---
        - Mark McGwire
        - Sammy Sosa
        - Ken Griffey

        # Team ranking
        ---
        - Chicago Cubs
        - St Louis Cardinals
        """
        let docs = try YAMLValue.parseAll(yaml)
        #expect(docs.count == 2)
        #expect(docs[0][0] == .string("Mark McGwire"))
        #expect(docs[1][0] == .string("Chicago Cubs"))
    }

    // MARK: - Additional fixtures

    @Test func testMappingWithColonValues() throws {
        let yaml = """
        url: http://example.com
        time: "12:30"
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["url"] == .string("http://example.com"))
        #expect(result["time"] == .string("12:30"))
    }

    @Test func testMixedSequence() throws {
        let yaml = """
        - string
        - 42
        - 3.14
        - true
        - false
        - null
        - ~
        - ''
        - ""
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result[0] == .string("string"))
        #expect(result[1] == .int(42))
        #expect(result[2] == .double(3.14))
        #expect(result[3] == .bool(true))
        #expect(result[4] == .bool(false))
        #expect(result[5] == .null)
        #expect(result[6] == .null)
        #expect(result[7] == .string(""))
        #expect(result[8] == .string(""))
    }

    @Test func testDeeplyNested() throws {
        let yaml = """
        level1:
          level2:
            level3:
              level4:
                value: deep
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["level1"]?["level2"]?["level3"]?["level4"]?["value"] == .string("deep"))
    }

    @Test func testMultilinePlainScalar() throws {
        let yaml = """
        plain:
          This unquoted scalar
          spans many lines.
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["plain"] == .string("This unquoted scalar spans many lines."))
    }

    @Test func testLargeMapping() throws {
        var yaml = ""
        for i in 0..<50 {
            yaml += "key\(i): value\(i)\n"
        }
        let result = try YAMLValue.parse(yaml)
        #expect(result.count == 50)
        #expect(result["key0"] == .string("value0"))
        #expect(result["key49"] == .string("value49"))
    }

    @Test func testUnicode() throws {
        let yaml = """
        emoji: "\u{1F600}"
        japanese: 日本語
        chinese: 中文
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["emoji"] == .string("\u{1F600}"))
        #expect(result["japanese"] == .string("日本語"))
        #expect(result["chinese"] == .string("中文"))
    }

    @Test func testBlockScalarBlankLines() throws {
        let yaml = """
        content: |
          line1

          line3
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["content"] == .string("line1\n\nline3\n"))
    }

    @Test func testFlowCollectionInMapping() throws {
        let yaml = """
        items: [a, b, c]
        count: 3
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["items"] == .sequence([.string("a"), .string("b"), .string("c")]))
        #expect(result["count"] == .int(3))
    }

    @Test func testDockerComposeLike() throws {
        let yaml = """
        version: "3.8"
        services:
          web:
            image: nginx
            ports:
              - "80:80"
              - "443:443"
            environment:
              NODE_ENV: production
              DEBUG: "false"
          db:
            image: postgres
            volumes:
              - db-data:/var/lib/postgresql/data
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["version"] == .string("3.8"))
        #expect(result["services"]?["web"]?["image"] == .string("nginx"))
        #expect(result["services"]?["web"]?["ports"]?[0] == .string("80:80"))
        #expect(result["services"]?["web"]?["environment"]?["NODE_ENV"] == .string("production"))
        #expect(result["services"]?["db"]?["image"] == .string("postgres"))
    }

    @Test func testGitHubActionsLike() throws {
        let yaml = """
        name: CI
        on:
          push:
            branches:
              - main
          pull_request:
            branches:
              - main
        jobs:
          build:
            runs-on: ubuntu-latest
            steps:
              - uses: actions/checkout@v4
              - name: Build
                run: make build
              - name: Test
                run: make test
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["name"] == .string("CI"))
        #expect(result["on"]?["push"]?["branches"]?[0] == .string("main"))
        #expect(result["jobs"]?["build"]?["runs-on"] == .string("ubuntu-latest"))
        #expect(result["jobs"]?["build"]?["steps"]?[0]?["uses"] == .string("actions/checkout@v4"))
        #expect(result["jobs"]?["build"]?["steps"]?[1]?["name"] == .string("Build"))
    }

    @Test func testKubernetesLike() throws {
        let yaml = """
        apiVersion: v1
        kind: Service
        metadata:
          name: my-service
          labels:
            app: MyApp
        spec:
          selector:
            app: MyApp
          ports:
            - protocol: TCP
              port: 80
              targetPort: 9376
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["apiVersion"] == .string("v1"))
        #expect(result["kind"] == .string("Service"))
        #expect(result["metadata"]?["name"] == .string("my-service"))
        #expect(result["spec"]?["ports"]?[0]?["port"] == .int(80))
    }

    // MARK: - Roundtrips

    @Test func testParseEmitParse() throws {
        let yaml = """
        name: test
        items:
          - one
          - two
          - three
        nested:
          key: value
          flag: true
        """
        let parsed1 = try YAMLValue.parse(yaml)
        let emitted = parsed1.yamlString()
        let parsed2 = try YAMLValue.parse(emitted)
        #expect(parsed1 == parsed2)
    }

    // MARK: - Hashable

    @Test func testHashable() throws {
        let a: YAMLValue = .string("hello")
        let b: YAMLValue = .string("hello")
        #expect(a.hashValue == b.hashValue)

        var set = Set<YAMLValue>()
        set.insert(.int(1))
        set.insert(.int(2))
        set.insert(.int(1))
        #expect(set.count == 2)
    }

    // MARK: - Error Handling

    @Test func testUnterminatedSingleQuote() throws {
        do {
            _ = try YAMLValue.parse("'unterminated")
            throw YAMLError.parseError("Expected error but none thrown")
        } catch {
            // Expected
        }
    }

    @Test func testUnterminatedDoubleQuote() throws {
        do {
            _ = try YAMLValue.parse("\"unterminated")
            throw YAMLError.parseError("Expected error but none thrown")
        } catch {
            // Expected
        }
    }

    @Test func testUnterminatedFlowSequence() throws {
        do {
            _ = try YAMLValue.parse("[1, 2, 3")
            throw YAMLError.parseError("Expected error but none thrown")
        } catch {
            // Expected
        }
    }

    @Test func testUnterminatedFlowMapping() throws {
        do {
            _ = try YAMLValue.parse("{a: 1, b: 2")
            throw YAMLError.parseError("Expected error but none thrown")
        } catch {
            // Expected
        }
    }

    @Test func testUndefinedAlias() throws {
        do {
            _ = try YAMLValue.parse("*undefined")
            throw YAMLError.parseError("Expected error but none thrown")
        } catch {
            // Expected
        }
    }

    // MARK: - ExpressibleBy Literals (Swift only)
    #if !SKIP

    @Test func testLiterals() throws {
        let str: YAMLValue = "hello"
        #expect(str == .string("hello"))

        let num: YAMLValue = 42
        #expect(num == .int(42))

        let dbl: YAMLValue = 3.14
        #expect(dbl == .double(3.14))

        let flag: YAMLValue = true
        #expect(flag == .bool(true))

        let arr: YAMLValue = [1, 2, 3]
        #expect(arr == .sequence([.int(1), .int(2), .int(3)]))

        let null: YAMLValue = nil
        #expect(null == .null)
    }

    #endif // !SKIP


    // MARK: - YAMLDecoder (Swift only)
    #if !SKIP

    @Test func testDecodeSimpleStruct() throws {
        let yaml = """
        name: Alice
        age: 30
        active: true
        score: 9.5
        """
        let decoder = YAMLDecoder()
        let person = try decoder.decode(TestPerson.self, from: yaml)
        #expect(person.name == "Alice")
        #expect(person.age == 30)
        #expect(person.active == true)
        #expect(person.score == 9.5)
    }

    @Test func testDecodeNestedStruct() throws {
        let yaml = """
        name: Alice
        address:
          city: NYC
          zip: 10001
        """
        let decoder = YAMLDecoder()
        let person = try decoder.decode(TestPersonWithAddress.self, from: yaml)
        #expect(person.name == "Alice")
        #expect(person.address.city == "NYC")
        #expect(person.address.zip == 10001)
    }

    @Test func testDecodeArray() throws {
        let yaml = """
        - 1
        - 2
        - 3
        """
        let decoder = YAMLDecoder()
        let numbers = try decoder.decode([Int].self, from: yaml)
        #expect(numbers == [1, 2, 3])
    }

    @Test func testDecodeArrayOfStructs() throws {
        let yaml = """
        - name: Alice
          age: 25
        - name: Bob
          age: 30
        """
        let decoder = YAMLDecoder()
        let people = try decoder.decode([TestPersonBasic].self, from: yaml)
        #expect(people.count == 2)
        #expect(people[0].name == "Alice")
        #expect(people[1].name == "Bob")
    }

    @Test func testDecodeOptionals() throws {
        let yaml = """
        name: Alice
        nickname: null
        """
        let decoder = YAMLDecoder()
        let person = try decoder.decode(TestPersonOptional.self, from: yaml)
        #expect(person.name == "Alice")
        #expect(person.nickname == nil)
    }

    // MARK: - YAMLEncoder

    @Test func testEncodeSimpleStruct() throws {
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(TestPersonBasic(name: "Alice", age: 30))
        #expect(yaml.contains("name: Alice"))
        #expect(yaml.contains("age: 30"))
    }

    @Test func testEncodeArray() throws {
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode([1, 2, 3])
        #expect(yaml.contains("- 1"))
        #expect(yaml.contains("- 2"))
        #expect(yaml.contains("- 3"))
    }

    @Test func testEncodeDecodeRoundtrip() throws {
        let original = TestConfig(name: "test", count: 42, ratio: 3.14, enabled: true)
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(original)
        let decoder = YAMLDecoder()
        let decoded = try decoder.decode(TestConfig.self, from: yaml)
        #expect(decoded == original)
    }

    @Test func testEncodeNestedRoundtrip() throws {
        let original = TestOuter(name: "test", inner: TestInner(x: 1, y: 2), tags: ["a", "b", "c"])
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(original)
        let decoder = YAMLDecoder()
        let decoded = try decoder.decode(TestOuter.self, from: yaml)
        #expect(decoded == original)
    }

    #endif // !SKIP
}

// Test types for Codable tests (Swift only, not transpiled)
#if !SKIP
struct TestPerson: Codable, Equatable {
    let name: String
    let age: Int
    let active: Bool
    let score: Double
}

struct TestAddress: Codable, Equatable {
    let city: String
    let zip: Int
}

struct TestPersonWithAddress: Codable, Equatable {
    let name: String
    let address: TestAddress
}

struct TestPersonBasic: Codable, Equatable {
    let name: String
    let age: Int
}

struct TestPersonOptional: Codable, Equatable {
    let name: String
    let nickname: String?
}

struct TestConfig: Codable, Equatable {
    let name: String
    let count: Int
    let ratio: Double
    let enabled: Bool
}

struct TestInner: Codable, Equatable {
    let x: Int
    let y: Int
}

struct TestOuter: Codable, Equatable {
    let name: String
    let inner: TestInner
    let tags: [String]
}
#endif
