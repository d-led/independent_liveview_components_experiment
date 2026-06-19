#!/usr/bin/env bash

set -euo pipefail

# Resolve directories relatively to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "========================================="
echo "Running tests for all Elixir workspace apps..."
echo "========================================="

echo ""
echo "--> Running Main App tests..."
cd "${ROOT_DIR}/main_app"
mix test

echo ""
echo "--> Running Global Service tests..."
cd "${ROOT_DIR}/global_service"
mix test

echo ""
echo "--> Running Sessions Service (Private Service) tests..."
cd "${ROOT_DIR}/private_service"
mix test

echo ""
echo "========================================="
echo "✓ All test suites passed successfully!"
echo "========================================="
