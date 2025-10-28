#!/usr/bin/env bash
set -euo pipefail

command -v staticcheck &> /dev/null || go install honnef.co/go/tools/cmd/staticcheck@latest
command -v exhaustive &> /dev/null || go install github.com/nishanths/exhaustive/cmd/exhaustive@latest

staticcheck ./...
exhaustive ./...
