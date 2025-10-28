#!/usr/bin/env bash
set -euo pipefail

VERSION=$(git describe --tags 2>/dev/null || echo "dev")
go build -ldflags "-X github.com/supabase/auth/internal/utilities.Version=$VERSION" -buildvcs=false
go test ./... -coverprofile=coverage.out -coverpkg ./... -p 1 -race -v -count=1
./hack/coverage.sh
