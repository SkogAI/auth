#!/usr/bin/env bash
set -euo pipefail

go mod download
go mod verify
go vet ./...

VERSION="skogai-0.0.1"
go build -ldflags "-X github.com/supabase/auth/internal/utilities.Version=$VERSION"
./auth version
