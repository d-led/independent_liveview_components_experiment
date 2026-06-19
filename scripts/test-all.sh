#!/usr/bin/env bash

set -euo pipefail

# Resolve directories relatively to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

SKIP_DIALYZER="${SKIP_DIALYZER:-false}"

run_quality_gates() {
  local app_dir="$1"
  local app_name="$2"

  echo ""
  echo "=================================================="
  echo "Running Quality Gates for ${app_name}..."
  echo "=================================================="
  cd "${ROOT_DIR}/${app_dir}"

  echo "--> Checking formatting..."
  mix format --check-formatted

  echo "--> Checking compilation warnings..."
  mix compile --warnings-as-errors

  echo "--> Running Credo static analysis (strict)..."
  mix credo --strict

  echo "--> Running Sobelow security analysis..."
  mix sobelow --config --exit

  if [ "${SKIP_DIALYZER}" = "true" ]; then
    echo "--> Skipping Dialyzer type checking..."
  else
    echo "--> Running Dialyzer type checking (this might take a while)..."
    mix dialyzer
  fi

  echo "--> Running ExUnit tests..."
  mix test
}

run_quality_gates "main_app" "Main App"
run_quality_gates "global_service" "Global Service"
run_quality_gates "private_service" "Sessions Service (Private Service)"

echo ""
echo "========================================="
echo "✓ All quality gates and test suites passed successfully!"
echo "========================================="
