#!/usr/bin/env bash
set -euo pipefail

command -v staticcheck &> /dev/null || go install honnef.co/go/tools/cmd/staticcheck@latest

echo "Unused code:"
staticcheck -checks U1000 ./...

echo ""
echo "Code used only in _test.go:"
staticcheck -checks U1000 -tests=false ./...
