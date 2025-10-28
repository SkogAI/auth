#!/usr/bin/env bash
set -euo pipefail

if docker compose version &>/dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

$DOCKER_COMPOSE -f docker-compose-dev.yml build --no-cache
$DOCKER_COMPOSE -f docker-compose-dev.yml up -d postgres
$DOCKER_COMPOSE -f docker-compose-dev.yml run auth sh -c "make migrate_dev"
$DOCKER_COMPOSE -f docker-compose-dev.yml down
