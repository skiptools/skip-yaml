
SkipXML is a Skip framework that provides YAML parsing.

It is currently a work in progress, and is not yet functional.

## Setup

To include this framework in your project, add the following
dependency to your `Package.swift` file:

```swift
let package = Package(
    name: "my-package",
    products: [
        .library(name: "MyProduct", targets: ["MyTarget"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.dev/skip-yaml.git", "0.0.0"..<"2.0.0"),
    ],
    targets: [
        .target(name: "MyTarget", dependencies: [
            .product(name: "SkipYAML", package: "skip-yaml")
        ])
    ]
)
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
