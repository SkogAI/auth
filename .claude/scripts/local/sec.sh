#!/usr/bin/env bash
set -euo pipefail

command -v gosec &> /dev/null || go install github.com/securego/gosec/v2/cmd/gosec@latest

gosec -quiet -exclude-generated ./...
gosec -quiet -tests -exclude-generated -exclude=G104 ./...
