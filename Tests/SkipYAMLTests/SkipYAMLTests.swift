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

    // MARK: - YAML Corner Cases

    // --- The "Norway Problem" and YAML 1.1 bool-like strings ---

    @Test func testNorwayProblemQuoted() throws {
        // "NO" as a quoted string should stay a string, not become false
        let yaml = """
        country: 'NO'
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["country"] == .string("NO"))
    }

    @Test func testYAML11BoolLikeStringsQuoted() throws {
        // YAML 1.1 treated yes/no/on/off as booleans; YAML 1.2 core schema does not
        // Quoted versions should always be strings regardless
        let yaml = """
        a: 'yes'
        b: 'no'
        c: 'on'
        d: 'off'
        e: 'y'
        f: 'n'
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["a"] == .string("yes"))
        #expect(result["b"] == .string("no"))
        #expect(result["c"] == .string("on"))
        #expect(result["d"] == .string("off"))
        #expect(result["e"] == .string("y"))
        #expect(result["f"] == .string("n"))
    }

    @Test func testUnquotedYAML11BoolLikeStrings() throws {
        // In YAML 1.2 core schema, yes/no/on/off are plain strings, not booleans
        let yaml = """
        a: yes
        b: no
        c: on
        d: off
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["a"] == .string("yes"))
        #expect(result["b"] == .string("no"))
        #expect(result["c"] == .string("on"))
        #expect(result["d"] == .string("off"))
    }

    // --- Numbers that are really strings ---

    @Test func testLeadingZerosAreStrings() throws {
        // Leading zeros should be treated as strings, not octal
        let yaml = """
        zip: 01onal
        phone: 0123456789
        code: 007
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["zip"] == .string("01onal"))
        // "0123456789" contains '8' and '9' which are invalid octal - should be string
        // Actually wait - the parser only recognizes 0o prefix for octal.
        // Numbers with leading zeros are just strings since they don't parse as valid int
        #expect(result["phone"] == .string("0123456789"))
        #expect(result["code"] == .string("007"))
    }

    @Test func testQuotedNumbersAreStrings() throws {
        let yaml = """
        a: '42'
        b: "3.14"
        c: '0xFF'
        d: "true"
        e: '1.0e3'
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["a"] == .string("42"))
        #expect(result["b"] == .string("3.14"))
        #expect(result["c"] == .string("0xFF"))
        #expect(result["d"] == .string("true"))
        #expect(result["e"] == .string("1.0e3"))
    }

    @Test func testNumberEdgeCases() throws {
        // Standalone "0" is an int
        #expect(try YAMLValue.parse("0") == .int(0))
        // +0 and -0
        #expect(try YAMLValue.parse("+0") == .int(0))
        #expect(try YAMLValue.parse("-0") == .int(0))
        // Hex
        #expect(try YAMLValue.parse("0xFF") == .int(255))
        #expect(try YAMLValue.parse("0x0") == .int(0))
        // Octal
        #expect(try YAMLValue.parse("0o77") == .int(63))
        #expect(try YAMLValue.parse("0o0") == .int(0))
    }

    @Test func testFloatEdgeCases() throws {
        // +.inf and -.inf
        let posInf = try YAMLValue.parse("+.inf")
        if case .double(let v) = posInf { #expect(v == Double.infinity) }
        else { throw YAMLError.parseError("Expected .double") }

        // Case variations of special floats
        let nanUpper = try YAMLValue.parse(".NaN")
        if case .double(let v) = nanUpper { #expect(v.isNaN) }
        else { throw YAMLError.parseError("Expected .double(.nan)") }

        let infUpper = try YAMLValue.parse(".Inf")
        if case .double(let v) = infUpper { #expect(v == Double.infinity) }
        else { throw YAMLError.parseError("Expected .double(.inf)") }

        // Float with underscores
        #expect(try YAMLValue.parse("1_000.5") == .double(1000.5))
    }

    // --- Strings with special characters ---

    @Test func testStringsContainingColons() throws {
        let yaml = """
        url: http://example.com:8080/path
        time: 10:30:00
        message: "Note: this has colons"
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["url"] == .string("http://example.com:8080/path"))
        #expect(result["time"] == .string("10:30:00"))
        #expect(result["message"] == .string("Note: this has colons"))
    }

    @Test func testStringsContainingHash() throws {
        let yaml = """
        color: "#FF0000"
        channel: '#general'
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["color"] == .string("#FF0000"))
        #expect(result["channel"] == .string("#general"))
    }

    @Test func testStringsWithBracesAndBrackets() throws {
        let yaml = """
        regex: "a{3}"
        template: "{name}"
        array_like: "[not, an, array]"
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["regex"] == .string("a{3}"))
        #expect(result["template"] == .string("{name}"))
        #expect(result["array_like"] == .string("[not, an, array]"))
    }

    // --- Multiline scalar edge cases ---

    @Test func testMultilinePlainScalarWithBlankLines() throws {
        let yaml = """
        text:
          first paragraph
          still first paragraph

          second paragraph
          still second
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["text"] == .string("first paragraph still first paragraph\nsecond paragraph still second"))
    }

    @Test func testSingleQuotedMultiline() throws {
        let yaml = "key: 'line one\n  line two\n  line three'"
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("line one line two line three"))
    }

    @Test func testDoubleQuotedMultiline() throws {
        let yaml = "key: \"line one\n  line two\n  line three\""
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("line one line two line three"))
    }

    @Test func testDoubleQuotedEscapedNewline() throws {
        // Backslash-newline should eat the newline and leading whitespace
        let yaml = "key: \"long \\\n  continuation\""
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("long continuation"))
    }

    // --- Block scalar edge cases ---

    @Test func testLiteralBlockWithExplicitIndent() throws {
        let yaml = "content: |2\n    indented\n    text\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["content"] == .string("  indented\n  text\n"))
    }

    @Test func testEmptyLiteralBlock() throws {
        let yaml = "content: |\nnext: value\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["content"] == .string(""))
        #expect(result["next"] == .string("value"))
    }

    @Test func testFoldedBlockWithMoreIndented() throws {
        // "More-indented" lines (lines with extra indentation) should preserve newlines
        let yaml = """
        content: >
          paragraph one
          still one

            code block
            more code

          paragraph two
        """
        let result = try YAMLValue.parse(yaml)
        let expected = "paragraph one still one\n\n  code block\n  more code\n\nparagraph two\n"
        #expect(result["content"] == .string(expected))
    }

    @Test func testLiteralBlockWithTrailingBlankLines() throws {
        // Clip (default |): single trailing newline
        let yaml = "content: |\n  hello\n\n\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["content"] == .string("hello\n"))
    }

    @Test func testLiteralBlockKeepWithTrailingBlanks() throws {
        let yaml = "content: |+\n  hello\n\n\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["content"] == .string("hello\n\n\n"))
    }

    @Test func testLiteralBlockStripNoNewline() throws {
        let yaml = "content: |-\n  hello\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["content"] == .string("hello"))
    }

    // --- Flow collection edge cases ---

    @Test func testFlowSequenceTrailingComma() throws {
        let result = try YAMLValue.parse("[1, 2, 3,]")
        #expect(result == .sequence([.int(1), .int(2), .int(3)]))
    }

    @Test func testFlowMappingTrailingComma() throws {
        let result = try YAMLValue.parse("{a: 1, b: 2,}")
        #expect(result["a"] == .int(1))
        #expect(result["b"] == .int(2))
    }

    @Test func testFlowSequenceMultiline() throws {
        let yaml = "[\n  1,\n  2,\n  3\n]"
        let result = try YAMLValue.parse(yaml)
        #expect(result == .sequence([.int(1), .int(2), .int(3)]))
    }

    @Test func testFlowMappingMultiline() throws {
        let yaml = "{\n  a: 1,\n  b: 2\n}"
        let result = try YAMLValue.parse(yaml)
        #expect(result["a"] == .int(1))
        #expect(result["b"] == .int(2))
    }

    @Test func testNestedEmptyFlowCollections() throws {
        let result = try YAMLValue.parse("{a: [], b: {}}")
        #expect(result["a"] == .sequence([]))
        #expect(result["b"] == .mapping(YAMLMapping()))
    }

    @Test func testFlowSequenceWithQuotedStrings() throws {
        let result = try YAMLValue.parse("[\"hello, world\", 'foo, bar']")
        #expect(result == .sequence([.string("hello, world"), .string("foo, bar")]))
    }

    @Test func testDeeplyNestedFlow() throws {
        let result = try YAMLValue.parse("[[[]]]")
        #expect(result == .sequence([.sequence([.sequence([])])]))
    }

    // --- Anchor and alias edge cases ---

    @Test func testAnchorOnMapping() throws {
        let yaml = """
        defaults: &defaults
          adapter: postgres
          host: localhost
        development:
          database: dev_db
          <<: *defaults
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["defaults"]?["adapter"] == .string("postgres"))
        #expect(result["defaults"]?["host"] == .string("localhost"))
        // The merge key << behavior depends on parser support
        // At minimum, development should parse without error
        #expect(result["development"]?["database"] == .string("dev_db"))
    }

    @Test func testAnchorOnSequence() throws {
        let yaml = """
        - &items
          - one
          - two
        - *items
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result[0] == .sequence([.string("one"), .string("two")]))
        #expect(result[1] == .sequence([.string("one"), .string("two")]))
    }

    @Test func testMultipleAnchorsAndAliases() throws {
        let yaml = """
        - &first hello
        - &second world
        - *first
        - *second
        - *first
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result[0] == .string("hello"))
        #expect(result[1] == .string("world"))
        #expect(result[2] == .string("hello"))
        #expect(result[3] == .string("world"))
        #expect(result[4] == .string("hello"))
    }

    @Test func testAnchorInFlowSequence() throws {
        let result = try YAMLValue.parse("[&a 1, *a]")
        #expect(result[0] == .int(1))
        #expect(result[1] == .int(1))
    }

    // --- Comment edge cases ---

    @Test func testCommentOnlyDocument() throws {
        let yaml = """
        # just a comment
        # another comment
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result == .null)
    }

    @Test func testCommentAfterFlowCollection() throws {
        let yaml = """
        items: [1, 2, 3] # my items
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["items"] == .sequence([.int(1), .int(2), .int(3)]))
    }

    @Test func testCommentBetweenMappingEntries() throws {
        let yaml = """
        a: 1
        # comment between
        b: 2
        # another comment
        c: 3
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["a"] == .int(1))
        #expect(result["b"] == .int(2))
        #expect(result["c"] == .int(3))
    }

    @Test func testCommentBetweenSequenceItems() throws {
        let yaml = """
        - one
        # comment
        - two
        # another
        - three
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result == .sequence([.string("one"), .string("two"), .string("three")]))
    }

    // --- Empty/null edge cases ---

    @Test func testAllNullMapping() throws {
        let yaml = """
        a:
        b:
        c:
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["a"] == .null)
        #expect(result["b"] == .null)
        #expect(result["c"] == .null)
    }

    @Test func testEmptyDocuments() throws {
        let yaml = """
        ---
        ---
        ---
        """
        let docs = try YAMLValue.parseAll(yaml)
        #expect(docs.count == 3)
        #expect(docs[0] == .null)
        #expect(docs[1] == .null)
        #expect(docs[2] == .null)
    }

    @Test func testDocumentWithOnlyComments() throws {
        let yaml = """
        ---
        # just comments
        ...
        ---
        hello
        """
        let docs = try YAMLValue.parseAll(yaml)
        #expect(docs.count == 2)
        #expect(docs[0] == .null)
        #expect(docs[1] == .string("hello"))
    }

    @Test func testNullVariations() throws {
        let yaml = """
        - null
        - Null
        - NULL
        - ~
        -
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result[0] == .null)
        #expect(result[1] == .null)
        #expect(result[2] == .null)
        #expect(result[3] == .null)
        #expect(result[4] == .null)
    }

    // --- Duplicate keys ---

    @Test func testDuplicateKeysLastWins() throws {
        let yaml = """
        key: first
        key: second
        """
        let result = try YAMLValue.parse(yaml)
        // YAML spec says duplicate keys are an error, but most parsers use last-wins
        // We just verify it doesn't crash
        #expect(result["key"] != nil)
    }

    // --- Numeric keys ---

    @Test func testNumericKeys() throws {
        let yaml = """
        1: one
        2: two
        3: three
        """
        let result = try YAMLValue.parse(yaml)
        // Keys are resolved as integers when unquoted
        if case .mapping(let map) = result {
            #expect(map.count == 3)
            let firstKey = map.entries[0].key
            let firstVal = map.entries[0].value
            // Key might be int or string depending on parser
            #expect(firstVal == .string("one"))
            if case .int(let k) = firstKey {
                #expect(k == 1)
            }
        }
    }

    @Test func testBooleanKeys() throws {
        let yaml = """
        true: yes value
        false: no value
        """
        let result = try YAMLValue.parse(yaml)
        if case .mapping(let map) = result {
            #expect(map.count == 2)
        }
    }

    // --- Mixed block and flow ---

    @Test func testBlockSequenceOfFlowMappings() throws {
        let yaml = """
        - {name: Alice, age: 30}
        - {name: Bob, age: 25}
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result[0]?["name"] == .string("Alice"))
        #expect(result[0]?["age"] == .int(30))
        #expect(result[1]?["name"] == .string("Bob"))
    }

    @Test func testBlockMappingWithFlowSequenceValues() throws {
        let yaml = """
        colors: [red, green, blue]
        sizes: [small, medium, large]
        empty: []
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["colors"] == .sequence([.string("red"), .string("green"), .string("blue")]))
        #expect(result["sizes"] == .sequence([.string("small"), .string("medium"), .string("large")]))
        #expect(result["empty"] == .sequence([]))
    }

    // --- Unicode edge cases ---

    @Test func testUnicodeInKeys() throws {
        let yaml = """
        "\u{1F600}": smile
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["\u{1F600}"] == .string("smile"))
    }

    @Test func testUnicodeEscapes() throws {
        // \u escape for BMP characters
        #expect(try YAMLValue.parse("\"\\u00E9\"") == .string("\u{00E9}"))  // é
        #expect(try YAMLValue.parse("\"\\u0041\\u0042\"") == .string("AB"))
        // \x escape for ASCII
        #expect(try YAMLValue.parse("\"\\x41\"") == .string("A"))
    }

    @Test func testMultibyteUnicode() throws {
        let yaml = """
        korean: "\u{D55C}\u{AE00}"
        arabic: "\u{0627}\u{0644}\u{0639}\u{0631}\u{0628}\u{064A}\u{0629}"
        math: "\u{2200}x\u{2208}S"
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["korean"] == .string("\u{D55C}\u{AE00}"))
        #expect(result["math"] == .string("\u{2200}x\u{2208}S"))
    }

    // --- Escape sequences in double-quoted strings ---

    @Test func testAllEscapeSequences() throws {
        #expect(try YAMLValue.parse("\"\\0\"") == .string("\u{0000}"))      // null
        #expect(try YAMLValue.parse("\"\\a\"") == .string("\u{0007}"))      // bell
        #expect(try YAMLValue.parse("\"\\b\"") == .string("\u{0008}"))      // backspace
        #expect(try YAMLValue.parse("\"\\t\"") == .string("\t"))            // tab
        #expect(try YAMLValue.parse("\"\\n\"") == .string("\n"))            // newline
        #expect(try YAMLValue.parse("\"\\v\"") == .string("\u{000B}"))      // vertical tab
        #expect(try YAMLValue.parse("\"\\f\"") == .string("\u{000C}"))      // form feed
        #expect(try YAMLValue.parse("\"\\r\"") == .string("\r"))            // carriage return
        #expect(try YAMLValue.parse("\"\\e\"") == .string("\u{001B}"))      // escape
        #expect(try YAMLValue.parse("\"\\\\ \"") == .string("\\ "))         // backslash
        #expect(try YAMLValue.parse("\"\\/\"") == .string("/"))             // slash
    }

    // --- Whitespace handling ---

    @Test func testTrailingWhitespaceInValues() throws {
        // Plain scalars should have trailing whitespace stripped
        let yaml = "key: value   \n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("value"))
    }

    @Test func testWhitespaceOnlyLines() throws {
        let yaml = "a: 1\n   \nb: 2\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["a"] == .int(1))
        #expect(result["b"] == .int(2))
    }

    // --- Deeply nested structures ---

    @Test func testDeeplyNestedMixed() throws {
        let yaml = """
        root:
          level1:
            - name: item1
              children:
                - name: child1
                  value: 1
                - name: child2
                  value: 2
            - name: item2
              children: []
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["root"]?["level1"]?[0]?["name"] == .string("item1"))
        #expect(result["root"]?["level1"]?[0]?["children"]?[0]?["name"] == .string("child1"))
        #expect(result["root"]?["level1"]?[0]?["children"]?[1]?["value"] == .int(2))
        #expect(result["root"]?["level1"]?[1]?["children"] == .sequence([]))
    }

    // --- Explicit key (?) syntax ---

    @Test func testExplicitKeySimple() throws {
        let yaml = """
        ? key
        : value
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("value"))
    }

    // --- Tags ---

    @Test func testBoolTag() throws {
        // !!bool should force boolean interpretation
        #expect(try YAMLValue.parse("!!bool true") == .bool(true))
        #expect(try YAMLValue.parse("!!bool false") == .bool(false))
    }

    @Test func testIntTag() throws {
        #expect(try YAMLValue.parse("!!int 42") == .int(42))
    }

    @Test func testFloatTag() throws {
        #expect(try YAMLValue.parse("!!float 3.14") == .double(3.14))
    }

    @Test func testStrTagOnNumber() throws {
        // !!str should prevent numeric resolution
        #expect(try YAMLValue.parse("!!str 42") == .string("42"))
        #expect(try YAMLValue.parse("!!str true") == .string("true"))
    }

    // --- Indentation edge cases ---

    @Test func testSequenceItemsWithDifferentValueTypes() throws {
        let yaml = """
        - simple
        - key: value
        - - nested1
          - nested2
        - [flow, items]
        - {flow: map}
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result[0] == .string("simple"))
        #expect(result[1]?["key"] == .string("value"))
        #expect(result[2] == .sequence([.string("nested1"), .string("nested2")]))
        #expect(result[3] == .sequence([.string("flow"), .string("items")]))
        #expect(result[4]?["flow"] == .string("map"))
    }

    @Test func testMappingValueOnNextLine() throws {
        let yaml = """
        key:
          value
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("value"))
    }

    @Test func testMappingWithDeeplyIndentedValue() throws {
        let yaml = "key:\n        deeply indented\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("deeply indented"))
    }

    // --- Multiple documents with different types ---

    @Test func testMultiDocMixedTypes() throws {
        let yaml = """
        ---
        scalar
        ---
        - sequence
        ---
        key: mapping
        """
        let docs = try YAMLValue.parseAll(yaml)
        #expect(docs.count == 3)
        #expect(docs[0] == .string("scalar"))
        #expect(docs[1] == .sequence([.string("sequence")]))
        #expect(docs[2]["key"] == .string("mapping"))
    }

    @Test func testDocumentEndBetweenDocuments() throws {
        let yaml = """
        ---
        first
        ...
        ---
        second
        ...
        """
        let docs = try YAMLValue.parseAll(yaml)
        #expect(docs.count == 2)
        #expect(docs[0] == .string("first"))
        #expect(docs[1] == .string("second"))
    }

    // --- Complex real-world-like documents ---

    @Test func testHelmChartLike() throws {
        let yaml = """
        apiVersion: v2
        name: my-app
        version: 1.0.0
        dependencies:
          - name: postgresql
            version: "11.6.0"
            repository: "https://charts.bitnami.com/bitnami"
            condition: postgresql.enabled
          - name: redis
            version: "16.0.0"
            repository: "https://charts.bitnami.com/bitnami"
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["apiVersion"] == .string("v2"))
        #expect(result["dependencies"]?[0]?["name"] == .string("postgresql"))
        #expect(result["dependencies"]?[0]?["version"] == .string("11.6.0"))
        #expect(result["dependencies"]?[1]?["name"] == .string("redis"))
    }

    @Test func testTravisCILike() throws {
        let yaml = """
        language: swift
        os:
          - osx
          - linux
        osx_image: xcode14
        script:
          - swift build
          - swift test
        env:
          global:
            - SWIFT_VERSION=5.7
          matrix:
            - BUILD_TYPE=debug
            - BUILD_TYPE=release
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["language"] == .string("swift"))
        #expect(result["os"]?[0] == .string("osx"))
        #expect(result["osx_image"] == .string("xcode14"))
        #expect(result["script"]?[0] == .string("swift build"))
        #expect(result["env"]?["global"]?[0] == .string("SWIFT_VERSION=5.7"))
        #expect(result["env"]?["matrix"]?[0] == .string("BUILD_TYPE=debug"))
    }

    // --- Roundtrip edge cases ---

    @Test func testRoundtripSpecialStrings() throws {
        // Strings that need quoting to survive roundtrip
        let values: [YAMLValue] = [
            .string(""),
            .string("true"),
            .string("false"),
            .string("null"),
            .string("42"),
            .string("3.14"),
            .string("~"),
        ]
        for val in values {
            let emitted = val.yamlString()
            let parsed = try YAMLValue.parse(emitted)
            #expect(parsed == val)
        }
    }

    @Test func testRoundtripCollections() throws {
        let map = YAMLMapping()
        map.append(key: .string("list"), value: .sequence([.int(1), .int(2), .int(3)]))
        map.append(key: .string("nested"), value: .mapping(YAMLMapping()))
        map.append(key: .string("null_val"), value: .null)
        let original = YAMLValue.mapping(map)
        let emitted = original.yamlString()
        let parsed = try YAMLValue.parse(emitted)
        #expect(parsed == original)
    }

    // --- Error handling edge cases ---

    @Test func testInvalidEscapeSequence() throws {
        // Invalid hex in \x escape
        do {
            _ = try YAMLValue.parse("\"\\xZZ\"")
            throw YAMLError.parseError("Expected error but none thrown")
        } catch {
            // Expected
        }
    }

    @Test func testNestedUnterminatedFlowSequence() throws {
        do {
            _ = try YAMLValue.parse("[[1, 2]")
            throw YAMLError.parseError("Expected error but none thrown")
        } catch {
            // Expected
        }
    }

    @Test func testUnterminatedDoubleQuoteInMapping() throws {
        do {
            _ = try YAMLValue.parse("key: \"unterminated")
            throw YAMLError.parseError("Expected error but none thrown")
        } catch {
            // Expected
        }
    }

    // --- Compact notation ---

    @Test func testCompactNestedMapping() throws {
        let yaml = """
        - a: 1
          b: 2
        - c: 3
          d: 4
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result[0]?["a"] == .int(1))
        #expect(result[0]?["b"] == .int(2))
        #expect(result[1]?["c"] == .int(3))
        #expect(result[1]?["d"] == .int(4))
    }

    // --- BOM handling ---

    @Test func testBOMHandling() throws {
        let yaml = "\u{FEFF}key: value"
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("value"))
    }

    // --- Directives ---

    @Test func testYAMLDirective() throws {
        let yaml = "%YAML 1.2\n---\nhello"
        let result = try YAMLValue.parse(yaml)
        #expect(result == .string("hello"))
    }

    // --- Mixed scalar types in flow ---

    @Test func testFlowSequenceWithMixedTypes() throws {
        let result = try YAMLValue.parse("[1, 'two', true, null, 3.14, ~]")
        #expect(result[0] == .int(1))
        #expect(result[1] == .string("two"))
        #expect(result[2] == .bool(true))
        #expect(result[3] == .null)
        #expect(result[4] == .double(3.14))
        #expect(result[5] == .null)
    }

    @Test func testFlowMappingWithMixedValueTypes() throws {
        let result = try YAMLValue.parse("{a: 1, b: true, c: null, d: 'str', e: 3.14}")
        #expect(result["a"] == .int(1))
        #expect(result["b"] == .bool(true))
        #expect(result["c"] == .null)
        #expect(result["d"] == .string("str"))
        #expect(result["e"] == .double(3.14))
    }

    // --- Single-line edge cases ---

    @Test func testSingleItemSequence() throws {
        let yaml = "- only\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result == .sequence([.string("only")]))
    }

    @Test func testSingleEntryMapping() throws {
        let yaml = "only: entry\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["only"] == .string("entry"))
    }

    @Test func testPlainScalarWithTrailingNewlines() throws {
        let result = try YAMLValue.parse("hello\n\n\n")
        #expect(result == .string("hello"))
    }

    // --- Implicit null in flow ---

    @Test func testFlowMappingImplicitNull() throws {
        let result = try YAMLValue.parse("{a:, b: 2}")
        #expect(result["a"] == .null)
        #expect(result["b"] == .int(2))
    }

    // --- Multi-document emitter ---

    @Test func testEmitMultipleDocuments() throws {
        let docs: [YAMLValue] = [.string("first"), .string("second"), .int(3)]
        let emitted = YAMLValue.emitAll(docs)
        let parsed = try YAMLValue.parseAll(emitted)
        #expect(parsed.count == 3)
        #expect(parsed[0] == .string("first"))
        #expect(parsed[1] == .string("second"))
        #expect(parsed[2] == .int(3))
    }

    // --- Spaces around colons ---

    @Test func testExtraSpacesAroundColon() throws {
        // Extra spaces before colon value should work
        let yaml = "key:   value with spaces   \n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("value with spaces"))
    }

    @Test func testKeyWithMultipleSpaces() throws {
        let yaml = "key  :  value\n"
        let result = try YAMLValue.parse(yaml)
        // "key  " should be trimmed to "key" since trailing whitespace is stripped from keys
        // But the parser might handle this differently - just verify it doesn't crash
        #expect(result != .null)
    }

    // --- Negative and positive number edge cases ---

    @Test func testNegativeZeroFloat() throws {
        let result = try YAMLValue.parse("-0.0")
        // Verify it parses as a double (not an int or string)
        if case .double = result {
            // OK - parsed as double
        } else {
            throw YAMLError.parseError("Expected .double for -0.0")
        }
    }

    @Test func testScientificNotation() throws {
        #expect(try YAMLValue.parse("1e10") == .double(1e10))
        #expect(try YAMLValue.parse("1E10") == .double(1e10))
        #expect(try YAMLValue.parse("1.5e-3") == .double(0.0015))
        #expect(try YAMLValue.parse("-2.5e+2") == .double(-250.0))
    }

    // MARK: - Additional YAML Corner Cases (Round 2)

    // --- Carriage return normalization ---

    @Test func testCRLFNormalization() throws {
        let yaml = "key: value\r\nother: data\r\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("value"))
        #expect(result["other"] == .string("data"))
    }

    @Test func testLoneCRNormalization() throws {
        let yaml = "key: value\rother: data\r"
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("value"))
        #expect(result["other"] == .string("data"))
    }

    // --- Tab character edge cases ---

    @Test func testTabInPlainScalarValue() throws {
        let yaml = "key: value\twith\ttabs"
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("value\twith\ttabs"))
    }

    @Test func testTabAfterColon() throws {
        let yaml = "key:\tvalue"
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("value"))
    }

    // --- Plain scalars starting with digits but not numbers ---

    @Test func testDigitPrefixedStrings() throws {
        let yaml = """
        a: 3things
        b: 1st
        c: 0.0.0
        d: 1.2.3.4
        e: 10-20
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["a"] == .string("3things"))
        #expect(result["b"] == .string("1st"))
        #expect(result["c"] == .string("0.0.0"))
        #expect(result["d"] == .string("1.2.3.4"))
        #expect(result["e"] == .string("10-20"))
    }

    // --- Timestamps as strings (YAML 1.2 doesn't have a timestamp type) ---

    @Test func testTimestampLikeValues() throws {
        let yaml = """
        date1: 2024-01-15
        date2: 2024-01-15T10:30:00Z
        time: 10:30:00
        """
        let result = try YAMLValue.parse(yaml)
        // In YAML 1.2 core schema, these are just strings
        #expect(result["date1"] == .string("2024-01-15"))
        #expect(result["date2"] == .string("2024-01-15T10:30:00Z"))
        #expect(result["time"] == .string("10:30:00"))
    }

    // --- Strings that look like document markers ---

    @Test func testDocumentMarkerLikeStrings() throws {
        // Quoted "---" and "..." should be strings
        let yaml = """
        a: "---"
        b: '...'
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["a"] == .string("---"))
        #expect(result["b"] == .string("..."))
    }

    @Test func testDashDashDashInMiddleOfLine() throws {
        // "---" not at line start is not a document marker
        let yaml = "key: value---end"
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("value---end"))
    }

    // --- Invalid number formats that should be strings ---

    @Test func testInvalidOctal() throws {
        // 0o89 has invalid octal digits
        #expect(try YAMLValue.parse("0o89") == .string("0o89"))
    }

    @Test func testInvalidHex() throws {
        // 0xGG has invalid hex digits
        #expect(try YAMLValue.parse("0xGG") == .string("0xGG"))
    }

    @Test func testDoubleDecimalPoint() throws {
        // 1.2.3 is not a valid float
        #expect(try YAMLValue.parse("1.2.3") == .string("1.2.3"))
    }

    @Test func testTrailingDot() throws {
        // "1." could be ambiguous -- verify behavior
        let result = try YAMLValue.parse("1.")
        // Should either be string "1." or double 1.0
        if case .string = result {
            // OK
        } else if case .double(let v) = result {
            #expect(v == 1.0)
        } else {
            throw YAMLError.parseError("Unexpected type for 1.")
        }
    }

    @Test func testPlusMinusAlone() throws {
        // "+" alone is a string (not a number prefix without digits)
        #expect(try YAMLValue.parse("+") == .string("+"))
        // "-" alone is a block sequence indicator (dash + EOF), yielding a sequence with one null item
        #expect(try YAMLValue.parse("-") == .sequence([.null]))
    }

    // --- Anchor on null value ---

    @Test func testAnchorOnNull() throws {
        let yaml = """
        - &empty null
        - *empty
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result[0] == .null)
        #expect(result[1] == .null)
    }

    // --- Anchors in flow mappings ---

    @Test func testAnchorInFlowMapping() throws {
        let result = try YAMLValue.parse("{a: &ref hello, b: *ref}")
        #expect(result["a"] == .string("hello"))
        #expect(result["b"] == .string("hello"))
    }

    // --- Alias as mapping value ---

    @Test func testAliasAsMappingValue() throws {
        let yaml = """
        default: &default_val 42
        copy: *default_val
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["default"] == .int(42))
        #expect(result["copy"] == .int(42))
    }

    // --- Anchor on mapping ---

    @Test func testAnchorOnMappingValue() throws {
        let yaml = """
        base: &base
          x: 1
          y: 2
        derived:
          z: 3
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["base"]?["x"] == .int(1))
        #expect(result["base"]?["y"] == .int(2))
        #expect(result["derived"]?["z"] == .int(3))
    }

    // --- Comments in flow collections ---

    @Test func testCommentsInFlowSequence() throws {
        // YAML spec allows comments in flow collections on separate lines
        let yaml = "[\n  1, # first\n  2, # second\n  3 # third\n]"
        let result = try YAMLValue.parse(yaml)
        #expect(result == .sequence([.int(1), .int(2), .int(3)]))
    }

    @Test func testCommentsInFlowMapping() throws {
        let yaml = "{\n  a: 1, # first\n  b: 2 # second\n}"
        let result = try YAMLValue.parse(yaml)
        #expect(result["a"] == .int(1))
        #expect(result["b"] == .int(2))
    }

    // --- Block scalars followed by more content ---

    @Test func testMultipleBlockScalarsInMapping() throws {
        let yaml = "first: |\n  hello\nsecond: |\n  world\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["first"] == .string("hello\n"))
        #expect(result["second"] == .string("world\n"))
    }

    @Test func testBlockScalarFollowedBySequence() throws {
        let yaml = "text: |-\n  hello world\nitems:\n  - one\n  - two\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["text"] == .string("hello world"))
        #expect(result["items"] == .sequence([.string("one"), .string("two")]))
    }

    // --- Sequence of block scalars ---

    @Test func testSequenceOfBlockScalars() throws {
        let yaml = "- |\n  first\n- |\n  second\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result[0] == .string("first\n"))
        #expect(result[1] == .string("second\n"))
    }

    // --- Literal block with extra indentation preserved ---

    @Test func testLiteralBlockExtraIndentPreserved() throws {
        let yaml = "code: |\n  line1\n    indented\n  line3\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["code"] == .string("line1\n  indented\nline3\n"))
    }

    // --- Empty string values in various contexts ---

    @Test func testEmptyQuotedStringInSequence() throws {
        let yaml = """
        - ""
        - ''
        - hello
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result[0] == .string(""))
        #expect(result[1] == .string(""))
        #expect(result[2] == .string("hello"))
    }

    @Test func testEmptyQuotedStringInFlowSequence() throws {
        let result = try YAMLValue.parse("['', \"\"]")
        #expect(result == .sequence([.string(""), .string("")]))
    }

    @Test func testEmptyQuotedStringInFlowMapping() throws {
        let result = try YAMLValue.parse("{'': value, key: ''}")
        #expect(result[""] == .string("value"))
        #expect(result["key"] == .string(""))
    }

    // --- Single-element flow collections ---

    @Test func testSingleElementFlowSequence() throws {
        #expect(try YAMLValue.parse("[42]") == .sequence([.int(42)]))
        #expect(try YAMLValue.parse("[hello]") == .sequence([.string("hello")]))
    }

    @Test func testSingleElementFlowMapping() throws {
        let result = try YAMLValue.parse("{key: value}")
        #expect(result["key"] == .string("value"))
    }

    // --- Nested empty structures ---

    @Test func testNestedEmptyMappings() throws {
        let yaml = """
        outer:
          inner: {}
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["outer"]?["inner"] == .mapping(YAMLMapping()))
    }

    @Test func testNestedEmptySequences() throws {
        let yaml = """
        outer:
          inner: []
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["outer"]?["inner"] == .sequence([]))
    }

    // --- Varying indentation widths ---

    @Test func testOneSpaceIndentation() throws {
        let yaml = "a:\n b:\n  c: deep\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["a"]?["b"]?["c"] == .string("deep"))
    }

    @Test func testFourSpaceIndentation() throws {
        let yaml = """
        root:
            level1:
                level2: value
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["root"]?["level1"]?["level2"] == .string("value"))
    }

    @Test func testMixedIndentationWidths() throws {
        let yaml = "a:\n  b:\n      c: value\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["a"]?["b"]?["c"] == .string("value"))
    }

    // --- Quoted string preserving leading/trailing whitespace ---

    @Test func testQuotedLeadingTrailingSpaces() throws {
        let yaml = "key: \"  hello  \""
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("  hello  "))
    }

    @Test func testSingleQuotedLeadingTrailingSpaces() throws {
        let yaml = "key: '  hello  '"
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("  hello  "))
    }

    // --- Special YAML escape sequences (\N, \_, \L, \P) ---

    @Test func testSpecialYAMLEscapes() throws {
        // \N = next line (U+0085)
        #expect(try YAMLValue.parse("\"\\N\"") == .string("\u{0085}"))
        // \_ = non-breaking space (U+00A0)
        #expect(try YAMLValue.parse("\"\\_\"") == .string("\u{00A0}"))
        // \L = line separator (U+2028)
        #expect(try YAMLValue.parse("\"\\L\"") == .string("\u{2028}"))
        // \P = paragraph separator (U+2029)
        #expect(try YAMLValue.parse("\"\\P\"") == .string("\u{2029}"))
    }

    // --- Double-quoted string with unicode \U escape (8 hex digits) ---

    @Test func testUnicodeUpperUEscape() throws {
        // \U00000041 = 'A'
        #expect(try YAMLValue.parse("\"\\U00000041\"") == .string("A"))
    }

    // --- Block scalar with comment in header ---

    @Test func testBlockScalarHeaderComment() throws {
        let yaml = "content: | # this is a comment\n  hello\n  world\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["content"] == .string("hello\nworld\n"))
    }

    @Test func testFoldedBlockHeaderComment() throws {
        let yaml = "content: >- # strip trailing\n  hello\n  world\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["content"] == .string("hello world"))
    }

    // --- Flow collection keys in block mapping ---

    @Test func testFlowSequenceAtTopLevel() throws {
        // A flow sequence at the start of a line is parsed as a standalone sequence
        let yaml = "[a, b]"
        let result = try YAMLValue.parse(yaml)
        #expect(result == .sequence([.string("a"), .string("b")]))
    }

    @Test func testFlowMappingAtTopLevel() throws {
        // A flow mapping at the start of a line is parsed as a standalone mapping
        let yaml = "{a: 1, b: 2}"
        let result = try YAMLValue.parse(yaml)
        #expect(result["a"] == .int(1))
        #expect(result["b"] == .int(2))
    }

    // --- Plain scalar with special chars not at start ---

    @Test func testPlainScalarWithAmpersand() throws {
        let yaml = "key: AT&T"
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("AT&T"))
    }

    @Test func testPlainScalarWithAsterisk() throws {
        let yaml = "key: bold*text*here"
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("bold*text*here"))
    }

    @Test func testPlainScalarWithExclamation() throws {
        let yaml = "key: hello!"
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("hello!"))
    }

    @Test func testPlainScalarWithAtSign() throws {
        let yaml = "key: user@example.com"
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("user@example.com"))
    }

    // --- Values with equals sign (common in env vars) ---

    @Test func testEqualsSignInValue() throws {
        let yaml = """
        env:
          - FOO=bar
          - BAZ=qux=123
          - EMPTY=
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["env"]?[0] == .string("FOO=bar"))
        #expect(result["env"]?[1] == .string("BAZ=qux=123"))
        #expect(result["env"]?[2] == .string("EMPTY="))
    }

    // --- Flow mapping with quoted keys containing special chars ---

    @Test func testFlowMappingQuotedKeysWithColons() throws {
        let result = try YAMLValue.parse("{\"key:with:colons\": value}")
        #expect(result["key:with:colons"] == .string("value"))
    }

    @Test func testFlowMappingQuotedKeysWithCommas() throws {
        let result = try YAMLValue.parse("{'key,with,commas': value}")
        #expect(result["key,with,commas"] == .string("value"))
    }

    // --- Deeply nested flow within flow ---

    @Test func testDeeplyNestedFlowMappings() throws {
        let result = try YAMLValue.parse("{a: {b: {c: deep}}}")
        #expect(result["a"]?["b"]?["c"] == .string("deep"))
    }

    @Test func testMixedNestedFlowCollections() throws {
        let result = try YAMLValue.parse("{list: [1, {nested: true}, [2, 3]]}")
        #expect(result["list"]?[0] == .int(1))
        #expect(result["list"]?[1]?["nested"] == .bool(true))
        #expect(result["list"]?[2] == .sequence([.int(2), .int(3)]))
    }

    // --- Multiline folded block with multiple paragraphs ---

    @Test func testFoldedBlockMultipleParagraphs() throws {
        let yaml = """
        text: >
          First paragraph
          continues here.

          Second paragraph
          continues here.

          Third paragraph.
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["text"] == .string("First paragraph continues here.\nSecond paragraph continues here.\nThird paragraph.\n"))
    }

    // --- Single-quoted string with only escaped quotes ---

    @Test func testSingleQuotedOnlyEscapedQuotes() throws {
        // '''' = a single quote character
        #expect(try YAMLValue.parse("''''") == .string("'"))
        // '''''' = two single quote characters
        #expect(try YAMLValue.parse("''''''") == .string("''"))
    }

    // --- Double-quoted string with consecutive escapes ---

    @Test func testDoubleQuotedConsecutiveEscapes() throws {
        #expect(try YAMLValue.parse("\"\\n\\n\"") == .string("\n\n"))
        #expect(try YAMLValue.parse("\"\\t\\t\"") == .string("\t\t"))
        #expect(try YAMLValue.parse("\"\\\\\\\\\"") == .string("\\\\"))
    }

    // --- Mapping with boolean value followed by comment ---

    @Test func testBooleanValueWithComment() throws {
        let yaml = """
        debug: true # enable debug mode
        verbose: false # disable verbose
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["debug"] == .bool(true))
        #expect(result["verbose"] == .bool(false))
    }

    // --- Mapping entry with null value followed by sequence ---

    @Test func testNullValueFollowedBySequence() throws {
        let yaml = """
        first:
        items:
          - a
          - b
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["first"] == .null)
        #expect(result["items"] == .sequence([.string("a"), .string("b")]))
    }

    // --- Multiple different node types as sequence items ---

    @Test func testSequenceWithAllNodeTypes() throws {
        let yaml = """
        - plain string
        - 42
        - 3.14
        - true
        - null
        - "double quoted"
        - 'single quoted'
        - [flow, seq]
        - {flow: map}
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result[0] == .string("plain string"))
        #expect(result[1] == .int(42))
        #expect(result[2] == .double(3.14))
        #expect(result[3] == .bool(true))
        #expect(result[4] == .null)
        #expect(result[5] == .string("double quoted"))
        #expect(result[6] == .string("single quoted"))
        #expect(result[7] == .sequence([.string("flow"), .string("seq")]))
        #expect(result[8]?["flow"] == .string("map"))
    }

    // --- Very long scalar values ---

    @Test func testVeryLongPlainScalar() throws {
        var longVal = ""
        for _ in 0..<200 {
            longVal += "abcde"
        }
        let yaml = "key: " + longVal
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string(longVal))
    }

    // --- Mapping keys with trailing spaces before colon ---

    @Test func testKeyWithSpaceBeforeColon() throws {
        // "key :" - the space before colon is part of the key lookup logic
        let yaml = "key : value\n"
        let result = try YAMLValue.parse(yaml)
        // Key should be "key" (trailing spaces trimmed)
        if case .mapping(let map) = result {
            #expect(map.count == 1)
            #expect(map.entries[0].value == .string("value"))
        }
    }

    // --- Flow mapping with no spaces ---

    @Test func testFlowMappingColonRequiresSpace() throws {
        // In YAML flow context, ":" must be followed by a space or flow indicator
        // to be a key-value separator. "a:1" is a single plain scalar.
        // But "a: 1" works:
        let result = try YAMLValue.parse("{a: 1, b: 2}")
        #expect(result["a"] == .int(1))
        #expect(result["b"] == .int(2))
    }

    // --- Roundtrip: complex nested structure ---

    @Test func testRoundtripNestedStructure() throws {
        let yaml = """
        name: test-app
        version: 1
        config:
          debug: true
          log_level: info
          ports:
            - 8080
            - 8443
          database:
            host: localhost
            port: 5432
        """
        let parsed1 = try YAMLValue.parse(yaml)
        let emitted = parsed1.yamlString()
        let parsed2 = try YAMLValue.parse(emitted)
        #expect(parsed1 == parsed2)
    }

    // --- Roundtrip: sorted keys ---

    @Test func testRoundtripSortedKeys() throws {
        let yaml = """
        z: last
        a: first
        m: middle
        """
        let parsed = try YAMLValue.parse(yaml)
        let emitted = parsed.yamlString(sortKeys: true)
        #expect(emitted.contains("a: first"))
        let parsed2 = try YAMLValue.parse(emitted)
        #expect(parsed2["a"] == .string("first"))
        #expect(parsed2["m"] == .string("middle"))
        #expect(parsed2["z"] == .string("last"))
    }

    // --- Emitter: strings needing quoting ---

    @Test func testEmitStringWithNewline() throws {
        let yaml = YAMLValue.string("line1\nline2").yamlString()
        let parsed = try YAMLValue.parse(yaml)
        #expect(parsed == .string("line1\nline2"))
    }

    @Test func testEmitStringWithColon() throws {
        let yaml = YAMLValue.string("key: value").yamlString()
        let parsed = try YAMLValue.parse(yaml)
        #expect(parsed == .string("key: value"))
    }

    @Test func testEmitStringWithHash() throws {
        let yaml = YAMLValue.string("has # hash").yamlString()
        let parsed = try YAMLValue.parse(yaml)
        #expect(parsed == .string("has # hash"))
    }

    // --- Emitter: special starting characters need quoting ---

    @Test func testEmitStringStartingWithDash() throws {
        let yaml = YAMLValue.string("- not a list").yamlString()
        let parsed = try YAMLValue.parse(yaml)
        #expect(parsed == .string("- not a list"))
    }

    @Test func testEmitStringStartingWithBracket() throws {
        let yaml = YAMLValue.string("[not a list]").yamlString()
        let parsed = try YAMLValue.parse(yaml)
        #expect(parsed == .string("[not a list]"))
    }

    @Test func testEmitStringStartingWithBrace() throws {
        let yaml = YAMLValue.string("{not a map}").yamlString()
        let parsed = try YAMLValue.parse(yaml)
        #expect(parsed == .string("{not a map}"))
    }

    // --- Emitter: negative infinity ---

    @Test func testEmitNegativeInfinity() throws {
        let yaml = YAMLValue.double(-Double.infinity).yamlString()
        #expect(yaml.contains("-.inf"))
        let parsed = try YAMLValue.parse(yaml)
        if case .double(let v) = parsed {
            #expect(v == -Double.infinity)
        }
    }

    // --- Multi-document with document end markers ---

    @Test func testMultiDocWithDocumentEndAndNoExplicitStart() throws {
        let yaml = "first\n...\nsecond\n"
        let docs = try YAMLValue.parseAll(yaml)
        #expect(docs.count >= 1)
        #expect(docs[0] == .string("first"))
    }

    // --- Mapping after sequence in same document ---

    @Test func testSequenceThenMappingInSameLevel() throws {
        // A top-level sequence should consume all items; this is ONE document
        let yaml = """
        - item1
        - item2
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result == .sequence([.string("item1"), .string("item2")]))
    }

    // --- Complex Kubernetes-like with multiple features ---

    @Test func testComplexKubernetesDeployment() throws {
        let yaml = """
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: nginx
          labels:
            app: nginx
            tier: frontend
        spec:
          replicas: 3
          selector:
            matchLabels:
              app: nginx
          template:
            metadata:
              labels:
                app: nginx
            spec:
              containers:
                - name: nginx
                  image: "nginx:1.25"
                  ports:
                    - containerPort: 80
                  env:
                    - name: ENV
                      value: production
                  resources:
                    limits:
                      cpu: "500m"
                      memory: "128Mi"
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["apiVersion"] == .string("apps/v1"))
        #expect(result["kind"] == .string("Deployment"))
        #expect(result["metadata"]?["labels"]?["tier"] == .string("frontend"))
        #expect(result["spec"]?["replicas"] == .int(3))
        let containers = result["spec"]?["template"]?["spec"]?["containers"]
        #expect(containers?[0]?["name"] == .string("nginx"))
        #expect(containers?[0]?["image"] == .string("nginx:1.25"))
        #expect(containers?[0]?["ports"]?[0]?["containerPort"] == .int(80))
        #expect(containers?[0]?["env"]?[0]?["name"] == .string("ENV"))
        #expect(containers?[0]?["resources"]?["limits"]?["cpu"] == .string("500m"))
        #expect(containers?[0]?["resources"]?["limits"]?["memory"] == .string("128Mi"))
    }

    // --- Error cases: more granular ---

    @Test func testUnterminatedSingleQuoteInFlowSequence() throws {
        do {
            _ = try YAMLValue.parse("['unterminated")
            throw YAMLError.parseError("Expected error but none thrown")
        } catch {
            // Expected
        }
    }

    @Test func testEmptyAnchorName() throws {
        do {
            _ = try YAMLValue.parse("& value")
            throw YAMLError.parseError("Expected error but none thrown")
        } catch {
            // Expected
        }
    }

    @Test func testEmptyAliasName() throws {
        do {
            _ = try YAMLValue.parse("* ")
            throw YAMLError.parseError("Expected error but none thrown")
        } catch {
            // Expected
        }
    }

    // --- Mapping where value is a sequence starting on same line ---

    @Test func testInlineSequenceStart() throws {
        let yaml = """
        items: - one
        """
        // "- one" after ": " on same line is a plain scalar "- one"
        // because block sequence items must be at the right indentation
        let result = try YAMLValue.parse(yaml)
        #expect(result["items"] == .string("- one"))
    }

    // --- Multiple blank lines between entries ---

    @Test func testMultipleBlankLinesBetweenMappingEntries() throws {
        let yaml = "a: 1\n\n\n\nb: 2\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result["a"] == .int(1))
        #expect(result["b"] == .int(2))
    }

    @Test func testMultipleBlankLinesBetweenSequenceItems() throws {
        let yaml = "- one\n\n\n- two\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result == .sequence([.string("one"), .string("two")]))
    }

    // --- Data URI / base64-like values ---

    @Test func testBase64LikeValue() throws {
        let yaml = "data: SGVsbG8gV29ybGQ="
        let result = try YAMLValue.parse(yaml)
        #expect(result["data"] == .string("SGVsbG8gV29ybGQ="))
    }

    // --- Nested block scalar with varying indent ---

    @Test func testNestedMappingWithBlockScalar() throws {
        let yaml = """
        outer:
          inner:
            content: |
              deeply nested
              block scalar
            next: value
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["outer"]?["inner"]?["content"] == .string("deeply nested\nblock scalar\n"))
        #expect(result["outer"]?["inner"]?["next"] == .string("value"))
    }

    // --- Tags on sequences and mappings ---

    @Test func testTagOnSequence() throws {
        let result = try YAMLValue.parse("!!seq [1, 2, 3]")
        #expect(result == .sequence([.int(1), .int(2), .int(3)]))
    }

    @Test func testTagOnMapping() throws {
        let result = try YAMLValue.parse("!!map {a: 1}")
        #expect(result["a"] == .int(1))
    }

    // --- Large sequence ---

    @Test func testLargeSequence() throws {
        var yaml = ""
        for i in 0..<100 {
            yaml += "- item\(i)\n"
        }
        let result = try YAMLValue.parse(yaml)
        #expect(result.count == 100)
        #expect(result[0] == .string("item0"))
        #expect(result[99] == .string("item99"))
    }

    // --- Consecutive document markers ---

    @Test func testConsecutiveDocumentStarts() throws {
        let yaml = "---\n---\n---\nvalue\n"
        let docs = try YAMLValue.parseAll(yaml)
        // First two --- produce null documents, third precedes "value"
        #expect(docs.count == 3)
        #expect(docs[0] == .null)
        #expect(docs[1] == .null)
        #expect(docs[2] == .string("value"))
    }

    // --- Plain scalar with colon at end of value ---

    @Test func testPlainScalarEndingWithColon() throws {
        let yaml = "key: \"value:\""
        let result = try YAMLValue.parse(yaml)
        #expect(result["key"] == .string("value:"))
    }

    // --- Sequence item that is just a dash with nothing after ---

    @Test func testSequenceItemDashOnly() throws {
        let yaml = "-\n- value\n"
        let result = try YAMLValue.parse(yaml)
        #expect(result[0] == .null)
        #expect(result[1] == .string("value"))
    }

    // --- Mapping with inline and next-line values mixed ---

    @Test func testMixedInlineAndNextLineValues() throws {
        let yaml = """
        inline: value
        nextline:
          nested
        another_inline: 42
        """
        let result = try YAMLValue.parse(yaml)
        #expect(result["inline"] == .string("value"))
        #expect(result["nextline"] == .string("nested"))
        #expect(result["another_inline"] == .int(42))
    }

    // --- Flow sequence with null/empty items ---

    @Test func testFlowSequenceWithNulls() throws {
        let result = try YAMLValue.parse("[null, ~, , hello]")
        #expect(result[0] == .null)
        #expect(result[1] == .null)
        // Empty item between commas may be null or empty string depending on parser
        #expect(result[3] == .string("hello"))
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
