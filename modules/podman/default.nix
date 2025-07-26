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
      echo "Testing connection to $USER@$HOST:$PORT"
      
      # Wait for SSH to be ready (up to 10 seconds)
      SSH_READY=false
      for i in {1..5}; do
        # Use native SSH timeout instead of timeout command
        if ssh -o StrictHostKeyChecking=no \
            -o ConnectTimeout=3 \
            -o UserKnownHostsFile=/dev/null \
            -o LogLevel=ERROR \
            -o ServerAliveInterval=2 \
            -o ServerAliveCountMax=1 \
            -i ~/.local/share/containers/podman/machine/machine \
            "$USER@$HOST" -p "$PORT" echo "SSH ready" >/dev/null 2>&1; then
          echo "SSH connection established"
          SSH_READY=true
          break
        fi
        echo "SSH not ready, waiting... ($i/5)"
        sleep 2
      done
      
      # If SSH still not ready, try to fix the network interface
      if [ "$SSH_READY" = false ]; then
        echo "SSH connection failed, attempting network interface reset..."
        
        # First, detect the network interface dynamically
        NETWORK_INTERFACE=""
        for iface in enp0s1 eth0 ens3 ens4; do
          if podman machine ssh -- "ip link show $iface" >/dev/null 2>&1; then
            NETWORK_INTERFACE="$iface"
            echo "Detected network interface: $NETWORK_INTERFACE"
            break
          fi
        done
        
        # Try to reset network interface using podman machine ssh
        if [ -n "$NETWORK_INTERFACE" ]; then
          if podman machine ssh -- "sudo ip link set $NETWORK_INTERFACE down && sudo ip link set $NETWORK_INTERFACE up" >/dev/null 2>&1; then
            echo "Reset network interface $NETWORK_INTERFACE"
            sleep 3
            
            # Check if SSH is working now
            if timeout 3 ssh -o StrictHostKeyChecking=no \
                -o ConnectTimeout=3 \
                -o UserKnownHostsFile=/dev/null \
                -o LogLevel=ERROR \
                -i ~/.local/share/containers/podman/machine/machine \
                "$USER@$HOST" -p "$PORT" echo "SSH ready" >/dev/null 2>&1; then
              echo "SSH connection restored after network reset"
              SSH_READY=true
            fi
          fi
        else
          echo "Could not detect network interface to reset"
        fi
        
        # If still not working, check machine status and restart if needed
        if [ "$SSH_READY" = false ]; then
          echo "Network reset failed, checking Podman machine status..."
          
          # Check if machine is running
          MACHINE_STATUS=$(podman machine list --format '{{.Name}}\t{{.Running}}' | grep -E '\s+true$' || echo "")
          
          if [ -n "$MACHINE_STATUS" ]; then
            echo "Machine is running but SSH is not working, attempting full restart..."
            podman machine stop >/dev/null 2>&1 || true
            sleep 3
            podman machine start >/dev/null 2>&1
          else
            echo "Machine is not running, starting it..."
            podman machine start >/dev/null 2>&1
          fi
          
          sleep 5
          
          # Update connection info after restart
          CONNECTION_URI=$(podman system connection list --format='{{.URI}}' | head -1)
          if [[ $CONNECTION_URI =~ ssh://([^@]+)@([^:]+):([0-9]+)(.*) ]]; then
            USER="''${BASH_REMATCH[1]}"
            HOST="''${BASH_REMATCH[2]}"
            PORT="''${BASH_REMATCH[3]}"
            REMOTE_SOCKET="''${BASH_REMATCH[4]}"
          fi
          
          # Try SSH one more time after machine restart
          if timeout 5 ssh -o StrictHostKeyChecking=no \
              -o ConnectTimeout=5 \
              -o UserKnownHostsFile=/dev/null \
              -o LogLevel=ERROR \
              -i ~/.local/share/containers/podman/machine/machine \
              "$USER@$HOST" -p "$PORT" echo "SSH ready" >/dev/null 2>&1; then
            echo "SSH connection established after machine restart"
            SSH_READY=true
          else
            echo "SSH connection failed even after machine restart"
            echo "Please check:"
            echo "  1. Is podman machine initialized? Try: podman machine init"
            echo "  2. Check podman machine status: podman machine list"
            echo "  3. Try manually: podman machine start"
            exit 1
          fi
        fi
      fi
      
      echo "Starting socket tunnel..."
      ssh -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o LogLevel=ERROR \
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
