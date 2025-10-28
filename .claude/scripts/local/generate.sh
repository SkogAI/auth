#!/usr/bin/env bash
set -euo pipefail

command -v oapi-codegen &> /dev/null || go install github.com/deepmap/oapi-codegen/cmd/oapi-codegen@latest

go generate ./...
