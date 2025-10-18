{ config, lib, pkgs, ... }:

let
  podmanStatus = pkgs.writeShellScriptBin "podman-status" ''
    #!/usr/bin/env bash

    echo "=== Podman Machine Status ==="
    podman machine list

    echo
    echo "=== Podman Connections ==="
    podman system connection list

    echo
    echo "=== Docker Socket Detection ==="
    GVPROXY_SOCKET=$(find /var/folders -name "podman-machine-*-api.sock" -type s 2>/dev/null | head -1)
    if [[ -n "$GVPROXY_SOCKET" ]]; then
      echo "✓ gvproxy API socket: $GVPROXY_SOCKET"
    else
      echo "✗ gvproxy API socket not found"
    fi

    if [[ -S "/tmp/podman.sock" ]]; then
      echo "✓ /tmp/podman.sock exists"
    else
      echo "✗ /tmp/podman.sock not found"
    fi

    echo
    echo "=== Environment ==="
    echo "DOCKER_HOST: ''${DOCKER_HOST:-not set}"

    echo
    echo "=== Disk Usage ==="
    podman machine ssh -- df -h / | grep -E '(Filesystem|/dev/vda)'
  '';

  podmanCleanup = pkgs.writeShellScriptBin "podman-cleanup" ''
    #!/usr/bin/env bash

    echo "Cleaning up Podman resources..."

    CONTAINER_COUNT=$(podman ps -aq | wc -l)
    if [[ $CONTAINER_COUNT -gt 0 ]]; then
      echo "Stopping and removing $CONTAINER_COUNT containers..."
      podman stop $(podman ps -aq) 2>/dev/null || true
      podman rm $(podman ps -aq) 2>/dev/null || true
    fi

    echo "Pruning system (images, volumes, networks)..."
    podman system prune -af --volumes

    echo
    echo "=== Cleanup Complete ==="
    podman machine ssh -- df -h / | grep -E '(Filesystem|/dev/vda)'
  '';
in
{
  home.packages = [
    podmanStatus
    podmanCleanup
  ];
}
