{ config, lib, pkgs, ... }:

let
  # Podman socket start script
  podmanSocketStart = pkgs.writeShellScriptBin "podman-socket-start" ''
    #!/usr/bin/env bash
    set -e
    
    rm -f /tmp/podman.sock
    
    CONNECTION_URI=$(podman system connection list --format='{{.URI}}' | head -1)
    
    if [[ $CONNECTION_URI =~ ssh://([^@]+)@([^:]+):([0-9]+)(.*) ]]; then
      USER="''${BASH_REMATCH[1]}"
      HOST="''${BASH_REMATCH[2]}"
      PORT="''${BASH_REMATCH[3]}"
      REMOTE_SOCKET="''${BASH_REMATCH[4]}"
      
      echo "Waiting for SSH to be ready..."
      
      # Wait for SSH to be ready (up to 10 seconds)
      SSH_READY=false
      for i in {1..3}; do
        if timeout 2 ssh -o StrictHostKeyChecking=no \
            -o ConnectTimeout=2 \
            -i ~/.local/share/containers/podman/machine/machine \
            "$USER@$HOST" -p "$PORT" echo "SSH ready" >/dev/null 2>&1; then
          echo "SSH connection established"
          SSH_READY=true
          break
        fi
        echo "SSH not ready, waiting... ($i/3)"
        sleep 2
      done
      
      # If SSH still not ready, try to fix the network interface
      if [ "$SSH_READY" = false ]; then
        echo "SSH connection failed, attempting network interface reset..."
        
        # Try to reset network interface using podman machine ssh
        if podman machine ssh -- 'sudo ip link set enp0s1 down && sudo ip link set enp0s1 up' >/dev/null 2>&1; then
          echo "Reset network interface enp0s1"
          sleep 3
          
          # Check if SSH is working now
          if timeout 2 ssh -o StrictHostKeyChecking=no \
              -o ConnectTimeout=2 \
              -i ~/.local/share/containers/podman/machine/machine \
              "$USER@$HOST" -p "$PORT" echo "SSH ready" >/dev/null 2>&1; then
            echo "SSH connection restored after network reset"
            SSH_READY=true
          fi
        fi
        
        # If still not working, restart the machine as last resort
        if [ "$SSH_READY" = false ]; then
          echo "Network reset failed, restarting Podman machine..."
          podman machine stop >/dev/null 2>&1 || true
          sleep 3
          podman machine start >/dev/null 2>&1
          sleep 5
          
          # Try SSH one more time after machine restart
          if timeout 5 ssh -o StrictHostKeyChecking=no \
              -o ConnectTimeout=5 \
              -i ~/.local/share/containers/podman/machine/machine \
              "$USER@$HOST" -p "$PORT" echo "SSH ready" >/dev/null 2>&1; then
            echo "SSH connection established after machine restart"
            SSH_READY=true
          else
            echo "SSH connection failed even after machine restart"
            exit 1
          fi
        fi
      fi
      
      echo "Starting socket tunnel..."
      ssh -o StrictHostKeyChecking=no \
          -o ControlPath=/tmp/podman-ssh-control \
          -o ControlMaster=yes \
          -i ~/.local/share/containers/podman/machine/machine \
          -L /tmp/podman.sock:"$REMOTE_SOCKET" \
          -N "$USER@$HOST" -p "$PORT" &
      
      sleep 2
      if [ -S /tmp/podman.sock ]; then
        echo "Podman socket started successfully at /tmp/podman.sock"
      else
        echo "Socket start failed - SSH tunnel may not be working"
        exit 1
      fi
    else
      echo "Failed to get Podman connection URI"
      exit 1
    fi
  '';

  # Podman socket stop script
  podmanSocketStop = pkgs.writeShellScriptBin "podman-socket-stop" ''
    #!/usr/bin/env bash
    set -e
    
    # Try graceful shutdown using SSH control socket
    if [ -e /tmp/podman-ssh-control ]; then
      ssh -o ControlPath=/tmp/podman-ssh-control -O exit dummy 2>/dev/null || true
      sleep 1
    fi
    
    # Fallback to pkill if process still exists
    pkill -f 'ssh.*podman.sock' 2>/dev/null || true
    
    # Clean up files
    rm -f /tmp/podman.sock /tmp/podman-ssh-control
    
    echo "Podman socket stopped"
  '';

  # Podman socket restart script
  podmanSocketRestart = pkgs.writeShellScriptBin "podman-socket-restart" ''
    #!/usr/bin/env bash
    set -e
    
    echo "Restarting Podman socket..."
    
    # Stop the socket
    ${podmanSocketStop}/bin/podman-socket-stop
    
    # Wait a moment for cleanup
    sleep 2
    
    # Start the socket
    ${podmanSocketStart}/bin/podman-socket-start
  '';

  # Podman socket status script
  podmanSocketStatus = pkgs.writeShellScriptBin "podman-socket-status" ''
    #!/usr/bin/env bash
    
    echo "=== Podman Socket Status ==="
    
    # Check if socket file exists
    if [ -S /tmp/podman.sock ]; then
      echo "✓ Socket file exists: /tmp/podman.sock"
    else
      echo "✗ Socket file not found: /tmp/podman.sock"
    fi
    
    # Check SSH tunnel
    if pgrep -f 'ssh.*podman.sock' > /dev/null; then
      echo "✓ SSH tunnel is running"
      echo "  PID: $(pgrep -f 'ssh.*podman.sock')"
    else
      echo "✗ SSH tunnel not running"
    fi
    
    # Check Podman machine status
    echo
    echo "=== Podman Machine Status ==="
    podman machine list
    
    echo
    echo "=== Podman Connections ==="
    podman system connection list
    
    # Check environment variables
    echo
    echo "=== Environment Variables ==="
    echo "DOCKER_HOST: ''${DOCKER_HOST:-not set}"
    echo "TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE: ''${TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE:-not set}"
    echo "TESTCONTAINERS_RYUK_DISABLED: ''${TESTCONTAINERS_RYUK_DISABLED:-not set}"
  '';

  # Package everything together
  podmanSocketPackage = pkgs.symlinkJoin {
    name = "podman-socket-manager";
    paths = [
      podmanSocketStart
      podmanSocketStop
      podmanSocketRestart
      podmanSocketStatus
    ];
  };
in
{
  # Add the podman socket management package to home packages
  home.packages = [ podmanSocketPackage ];
}