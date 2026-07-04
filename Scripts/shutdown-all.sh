#!/usr/bin/env bash
set -euo pipefail

# Stops every stack's containers, in reverse dependency order.
# dashboards-automation owns proxy_net (external: false), so it is stopped
# last, after every stack that joins that network as external: true.

STACKS_DIR="${STACKS_DIR:-/opt/docker/stacks}"

STACK_ORDER=(
  llm
  tools
  media-gaming
  auth
  infrastructure-networking
  dockge
  dashboards-automation
)

failed=()

for stack in "${STACK_ORDER[@]}"; do
  dir="$STACKS_DIR/$stack"
  if [[ ! -f "$dir/compose.yaml" ]]; then
    echo "Skipping $stack: no compose.yaml found in $dir" >&2
    continue
  fi

  echo "==> Stopping $stack"
  if ! (cd "$dir" && docker compose stop); then
    echo "Failed to stop $stack" >&2
    failed+=("$stack")
  fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "Failed to stop: ${failed[*]}" >&2
  exit 1
fi

echo "All stacks stopped."
