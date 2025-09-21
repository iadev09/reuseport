#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
WORK_DIR="$(dirname "$SCRIPT_DIR")"


cd "${WORK_DIR}" || exit

echo "Building Docker image..."

docker build -t reuseport . > /dev/null 2>&1
docker run --rm -it reuseport

