#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/simple-arithmetic-calculator-323459-323468/calculator_frontend"
mkdir -p "$WORKSPACE" && cd "$WORKSPACE"
# Package.swift
if [ ! -f "Package.swift" ]; then
  cat > Package.swift <<'SWIFT'
// swift-tools-version:5.8
import PackageDescription
let package = Package(
  name: "Calculator",
  products: [ .executable(name: "calculator", targets: ["Calculator"]), .library(name: "CalculatorLib", targets: ["CalculatorLib"]) ],
  targets: [
    .target(name: "CalculatorLib", path: "Sources/CalculatorLib"),
    .executableTarget(name: "Calculator", dependencies: ["CalculatorLib"], path: "Sources/Calculator"),
    .testTarget(name: "CalculatorTests", dependencies: ["CalculatorLib"], path: "Tests/CalculatorTests")
  ]
)
SWIFT
fi
# create directories
mkdir -p "$WORKSPACE/Sources/CalculatorLib" "$WORKSPACE/Sources/Calculator" "$WORKSPACE/Tests/CalculatorTests"
# Library source
if [ ! -f "Sources/CalculatorLib/Arithmetic.swift" ]; then
  cat > "Sources/CalculatorLib/Arithmetic.swift" <<'SWIFT'
public func add(_ a: Int, _ b: Int) -> Int { a + b }
public func sub(_ a: Int, _ b: Int) -> Int { a - b }
SWIFT
fi
# Executable source
if [ ! -f "Sources/Calculator/main.swift" ]; then
  cat > "Sources/Calculator/main.swift" <<'SWIFT'
import Foundation
import CalculatorLib
let args = CommandLine.arguments
if args.count == 3, let a = Int(args[1]), let b = Int(args[2]) {
  print(add(a,b))
} else {
  print("Usage: calculator <int> <int>")
}
SWIFT
fi
# Tests
if [ ! -f "Tests/CalculatorTests/CalculatorTests.swift" ]; then
  cat > "Tests/CalculatorTests/CalculatorTests.swift" <<'SWIFT'
import XCTest
@testable import CalculatorLib
final class CalculatorTests: XCTestCase {
  func testAdd() {
    XCTAssertEqual(add(2,3), 5)
  }
}
SWIFT
fi
# helper build script (always ensure content matches expected — overwrite)
cat > build.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f /etc/profile.d/swift.sh ] && source /etc/profile.d/swift.sh || true
cd "$SCRIPT_DIR"
swift build --configuration debug
BASH
chmod +x build.sh
# helper test script (always ensure content matches expected — overwrite)
cat > test.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f /etc/profile.d/swift.sh ] && source /etc/profile.d/swift.sh || true
cd "$SCRIPT_DIR"
if [ "${SWIFT_TEST_PARALLEL:-0}" = "1" ]; then
  swift test --parallel
else
  swift test
fi
BASH
chmod +x test.sh
