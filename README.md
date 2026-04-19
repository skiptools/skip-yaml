# SkipYAML

SkipYAML is a [Skip](https://skip.dev) framework that provides YAML parsing and serialization for both iOS and Android. It implements a pure-Swift YAML parser targeting the YAML 1.2 Core Schema, transpiled to Kotlin for Android via Skip.

## Features

- Parse YAML strings into a structured `YAMLValue` tree
- Serialize `YAMLValue` back to YAML strings
- Block and flow collections (sequences and mappings)
- All five scalar styles: plain, single-quoted, double-quoted, literal block (`|`), folded block (`>`)
- Block scalar chomping indicators (`-` strip, `+` keep)
- Multi-line plain scalar folding
- Anchors (`&name`) and aliases (`*name`)
- Tags (`!!str`, `!!int`, `!!null`, etc.)
- Multiple document support (`---` / `...`)
- YAML 1.2 Core Schema type resolution (null, bool, int, float)
- Comments (standalone and inline)
- Unicode support

## Setup

To include this framework in your project, add the following dependency to your `Package.swift` file:

```swift
.package(url: "https://source.skip.tools/skip-yaml.git", "0.0.0"..<"2.0.0")
```

And add it to your target dependencies:

```swift
.target(name: "MyTarget", dependencies: [
    .product(name: "SkipYAML", package: "skip-yaml")
])
```

## Usage

### Parsing YAML

Parse a YAML string into a `YAMLValue`:

```swift
import SkipYAML

let yaml = """
name: My App
version: 2.1
debug: false
servers:
  - host: example.com
    port: 443
  - host: backup.example.com
    port: 8443
tags: [production, stable]
"""

let config = try YAMLValue.parse(yaml)
```

Parse a multi-document YAML stream:

```swift
let docs = try YAMLValue.parseAll("---\nfirst\n---\nsecond\n")
// docs[0] == .string("first")
// docs[1] == .string("second")
```

Parse from UTF-8 `Data`:

```swift
let value = try YAMLValue.parse(data)
```

### Accessing Values

Use subscripts to navigate the parsed tree:

```swift
// String key subscript for mappings
let name = config["name"]              // .string("My App")
let host = config["servers"]?[0]?["host"] // .string("example.com")

// Integer index subscript for sequences
let firstTag = config["tags"]?[0]      // .string("production")
```

Extract typed values with convenience accessors:

```swift
config["name"]?.stringValue    // "My App"
config["version"]?.doubleValue // 2.1
config["debug"]?.boolValue     // false
config["servers"]?.count       // 2
```

Check value types:

```swift
config["name"]?.isScalar       // true
config["servers"]?.isCollection // true
config["missing"]?.isNull      // nil (key not found)
```

### YAMLValue Cases

`YAMLValue` is an enum with the following cases:

| Case | Description |
|------|-------------|
| `.null` | Null value (`null`, `~`, or empty) |
| `.bool(Bool)` | Boolean (`true` / `false`) |
| `.int(Int)` | Integer (decimal, hex `0x`, octal `0o`) |
| `.double(Double)` | Float (decimal, `.inf`, `-.inf`, `.nan`) |
| `.string(String)` | String (plain, single-quoted, double-quoted, block) |
| `.sequence([YAMLValue])` | Ordered list of values |
| `.mapping(YAMLMapping)` | Ordered key-value pairs |

### Working with Mappings

`YAMLMapping` preserves insertion order and supports duplicate keys:

```swift
let map = YAMLMapping()
map.append(key: .string("name"), value: .string("example"))
map.append(key: .string("count"), value: .int(42))

let yaml = YAMLValue.mapping(map)
yaml["name"]  // .string("example")
yaml["count"] // .int(42)

map.keys      // [.string("name"), .string("count")]
map.values    // [.string("example"), .int(42)]
map.count     // 2
```

Look up values by key:

```swift
map.value(forKey: "name")                      // .string("example")
map.value(forYAMLKey: .string("name"))         // .string("example")
```

### Emitting YAML

Serialize a `YAMLValue` back to a YAML string:

```swift
let value: YAMLValue = .mapping(map)
let output = value.yamlString()
// name: example
// count: 42
```

Options:

```swift
value.yamlString(sortKeys: true)   // alphabetical key order
value.yamlString(indent: 4)        // 4-space indentation
```

Emit multiple documents:

```swift
let docs: [YAMLValue] = [.string("first"), .string("second")]
let output = YAMLValue.emitAll(docs)
// ---
// first
// ---
// second
```

### Type Resolution

Plain (unquoted) scalars are automatically resolved to typed values using the YAML 1.2 Core Schema:

| YAML | Resolved type |
|------|---------------|
| `null`, `~`, `Null`, `NULL` | `.null` |
| `true`, `True`, `TRUE` | `.bool(true)` |
| `false`, `False`, `FALSE` | `.bool(false)` |
| `42`, `-17`, `0x1A`, `0o17` | `.int(...)` |
| `3.14`, `1.0e3`, `.inf`, `.nan` | `.double(...)` |
| everything else | `.string(...)` |

Quoted scalars (`'...'` or `"..."`) are always strings, regardless of content:

```yaml
version: '2.0'   # .string("2.0"), not .double
flag: "true"      # .string("true"), not .bool
```

### Error Handling

Parsing errors throw `YAMLError.parseError` with a message including line and column:

```swift
do {
    let value = try YAMLValue.parse("'unterminated")
} catch {
    // YAMLError.parseError("Unterminated single-quoted scalar at line 1, column 13")
}
```

## Building

This project is a Swift Package Manager module that uses the
[Skip](https://skip.dev) plugin to build the package for both iOS and Android.

## Testing

The module can be tested using the standard `swift test` command
or by running the test target for the macOS destination in Xcode,
which will run the Swift tests as well as the transpiled
Kotlin JUnit tests in the Robolectric Android simulation environment.

Parity testing can be performed with `skip test`,
which will output a table of the test results for both platforms.

## License

This software is licensed under the
[Mozilla Public License 2.0](https://www.mozilla.org/MPL/).
