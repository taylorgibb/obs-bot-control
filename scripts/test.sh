#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

swiftc -swift-version 5 -o "$work/probe" "$root/Sources/Protocol.swift" "$root/Tests/main.swift"
"$work/probe" > "$work/actual.txt"
diff -u "$root/Tests/expected.txt" "$work/actual.txt"
echo "protocol tests passed"
