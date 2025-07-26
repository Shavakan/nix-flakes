{ config, lib, pkgs, ... }:

with lib;

let
  # Define the available themes
  themes = {
    nord = {
      name = "nord";
      description = "Nord theme with blue accent colors";
      dirColors = {
        directory = "01;34"; # Bold blue
        executable = "01;32"; # Bold green
        symlink = "01;36"; # Bold cyan
      };
      p10kColors = {
        directory = 33; # Bright blue
        gitClean = 76; # Green
        gitModified = 214; # Orange
        gitUntracked = 39; # Light blue
        executable = 70; # Green
      };
    };

    monokai = {
      name = "monokai";
      description = "Monokai theme with vibrant colors";
      dirColors = {
        directory = "01;35"; # Bold magenta
        executable = "01;32"; # Bold green
        symlink = "01;36"; # Bold cyan
      };
      p10kColors = {
        directory = 197; # Pink/magenta
        gitClean = 76; # Green
        gitModified = 208; # Orange
        gitUntracked = 45; # Cyan
        executable = 70; # Green
      };
    };

    "solarized-dark" = {
      name = "solarized-dark";
      description = "Solarized Dark theme";
      dirColors = {
        directory = "01;34"; # Bold blue
        executable = "01;32"; # Bold green
        symlink = "01;36"; # Bold cyan
      };
      p10kColors = {
        directory = 33; # Blue
        gitClean = 64; # Green
        gitModified = 136; # Yellow
        gitUntracked = 37; # Cyan
        executable = 64; # Green
      };
    };

    "solarized-light" = {
      name = "solarized-light";
      description = "Solarized Light theme";
      dirColors = {
        directory = "01;34"; # Bold blue
        executable = "01;32"; # Bold green
        symlink = "01;36"; # Bold cyan
      };
      p10kColors = {
        directory = 33; # Blue
        gitClean = 64; # Green
        gitModified = 136; # Yellow
        gitUntracked = 37; # Cyan
        executable = 64; # Green
      };
    };
  };

  # Default theme
  defaultTheme = "nord";

  # Get user-configured theme or use default
  selectedTheme = themes.${config.themes.selected or defaultTheme};
in
{
  options.themes = {
    selected = mkOption {
      type = types.enum (attrNames themes);
      default = defaultTheme;
      description = "Selected color theme for terminal and user interface";
      example = "solarized-dark";
    };
  };

  config = {
    # Store the current theme where shell scripts can access it
    home.file.".current-theme".text = selectedTheme.name;

    # Generate LS_COLORS with vivid if available
    home.activation.setupVividColors = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if command -v vivid >/dev/null 2>&1; then
        # Generate LS_COLORS using vivid with the selected theme
        $DRY_RUN_CMD vivid generate "${selectedTheme.name}" > $HOME/.vivid_colors || true
      fi
    '';

    # Export the selected theme information for other modules to use
    _module.args.selectedTheme = selectedTheme;
  };
}
