#!/usr/bin/env bash
set -euo pipefail

# Recreates every stack's containers from their current compose.yaml/.env, in
# dependency order. Unlike startup-all.sh (docker compose start, which only
# resumes already-created containers), this re-reads each stack's config and
# recreates any container whose image, environment, or ports have changed.
# infrastructure-networking owns proxy_net (external: false) and must come up
# first; every other stack (except dockge, which isn't on proxy_net) joins
# it as external: true.

STACKS_DIR="${STACKS_DIR:-/opt/docker/stacks}"

STACK_ORDER=(
  infrastructure-networking
  dashboards-automation
  dockge
  auth
  media-gaming
  tools
  llm
)

failed=()

for stack in "${STACK_ORDER[@]}"; do
  dir="$STACKS_DIR/$stack"
  if [[ ! -f "$dir/compose.yaml" ]]; then
    echo "Skipping $stack: no compose.yaml found in $dir" >&2
    continue
  fi

  echo "==> Rebuilding $stack"
  if ! (cd "$dir" && docker compose up -d); then
    echo "Failed to rebuild $stack" >&2
    failed+=("$stack")
  fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "Failed to rebuild: ${failed[*]}" >&2
  exit 1
fi

echo "All stacks rebuilt."
