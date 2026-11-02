#!/usr/bin/env bash

set -euo pipefail

# Phoenix.Presence derives the replication topic from the presence module's
# name (phx_presence:Elixir.Cluster.Presence_shard<n>). Each app owns its own
# copy of the module -- three independent teams, three independent releases --
# but the name is a cluster-wide contract. A differently named module is a
# separate presence universe that never replicates, and the failure is silent:
# the tracker starts, tracks, and every other app reports an empty lobby.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_MODULE="Cluster.Presence"
APPS=(main_app private_service global_service)

failures=0

for app in "${APPS[@]}"; do
  files="$(grep -rl 'use Phoenix.Presence' --include='*.ex' "${ROOT_DIR}/${app}/lib" || true)"
  count="$(printf '%s\n' "${files}" | grep -c . || true)"

  if [[ "${count}" -ne 1 ]]; then
    echo "✗ ${app}: expected exactly one presence module, found ${count}" >&2
    failures=1
    continue
  fi

  if ! grep -q "defmodule ${EXPECTED_MODULE} do" "${files}"; then
    echo "✗ ${app}: presence module must be ${EXPECTED_MODULE}, found in ${files}" >&2
    failures=1
  fi
done

if [[ "${failures}" -ne 0 ]]; then
  exit 1
fi

echo "✓ all apps declare the same presence identity (${EXPECTED_MODULE})"
