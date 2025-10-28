#!/usr/bin/env bash
set -euo pipefail

./.claude/scripts/local/vet.sh
./.claude/scripts/local/sec.sh
./.claude/scripts/local/static.sh
./.claude/scripts/local/build.sh
