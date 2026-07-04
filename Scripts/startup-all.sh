#!/usr/bin/env bash
set -euo pipefail

# Starts every stack's containers, in dependency order.
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

  echo "==> Starting $stack"
  if ! (cd "$dir" && docker compose start); then
    echo "Failed to start $stack" >&2
    failed+=("$stack")
  fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "Failed to start: ${failed[*]}" >&2
  exit 1
fi

echo "All stacks started."
