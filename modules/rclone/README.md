# Rclone Modules for Nix-Flakes

This directory contains a set of modules for managing Rclone in a Nix environment.

## Module Structure

- **default.nix**: Main entry point that imports all modules and contains the base rclone configuration
- **mount.nix**: Configuration for mounting remote storage via rclone
- **launchd.nix**: macOS launchd integration for automatic mounting
- **cd-rclone/**: Module for convenient navigation to rclone mount locations

## Usage

### Simple Import

Simply import the directory in your configuration:

```nix
{
  imports = [
    ./modules/rclone
    # other imports...
  ];
}
```

This will import all the rclone-related modules in one go.

### Configuration

Each component can be configured independently:

```nix
{
  # Configure rclone base service
  services.rclone = {
    enable = true;
    configFile = ./modules/agenix/rclone.conf.age;
  };

  # Configure rclone mounting service
  services.rclone-mount = {
    enable = true;
    mounts = [
      {
        remote = "aws-example:bucket";
        mountPoint = "${config.home.homeDirectory}/mnt/rclone";
        allowOther = false;
      }
    ];
  };

  # Configure cd-rclone for easy navigation
  programs.cd-rclone = {
    enable = true;
    extraDirs = {
      kube = "kubeconfigs";
      docs = "documents";
    };
  };

  # Enable launchd integration (macOS only)
  services.rclone-launchd = {
    enable = true;
  };
}
```

## Module Dependencies

The modules have the following dependency structure:

- **default.nix**: Base service, no dependencies
- **mount.nix**: Uses services from default.nix but has no direct import dependencies
- **cd-rclone**: Functional without direct dependencies on other modules
- **launchd.nix**: Depends on mount.nix being enabled but doesn't enforce it

The design avoids circular dependencies while maintaining the proper functionality chain. When using them, prefer to enable the services in this order in your configuration:

1. `services.rclone`
2. `services.rclone-mount`
3. `programs.cd-rclone` 
4. `services.rclone-launchd`

The dependencies are automatically managed when imported via default.nix.
