#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
WORK_DIR="$(dirname "$SCRIPT_DIR")"

cd "${WORK_DIR}" || exit

source .venv/bin/activate

chmod +x tests/*.{sh,py}

./tests/docker_run.sh | ./tests/test_uniform.py