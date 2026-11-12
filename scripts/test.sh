#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
xcrun swiftc -module-cache-path "$(pwd)/build/module-cache" \
    Sources/GPUModel.swift Tests/main.swift -o build/GPUModelTests
build/GPUModelTests
