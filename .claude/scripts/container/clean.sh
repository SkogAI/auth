#!/usr/bin/env bash
set -euo pipefail

if docker compose version &>/dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

$DOCKER_COMPOSE -f docker-compose-dev.yml rm -fsv
