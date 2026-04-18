// Copyright 2024-2026 Skip
// SPDX-License-Identifier: MPL-2.0

import Testing
import OSLog
import Foundation

let logger: Logger = Logger(subsystem: "SkipYAML", category: "Tests")

@Suite struct SkipYAMLTests {
    @Test func skipYAMLTest() throws {
        #expect(1 + 2 == 3)
    }
}
