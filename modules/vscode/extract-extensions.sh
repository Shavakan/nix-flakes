#!/usr/bin/env bash
# Script to extract currently installed VS Code extensions and format them for Nix configuration
# Execute: chmod +x ./extract-extensions.sh

# Make this script executable with: chmod +x extract-extensions.sh

# Check if VS Code is installed
if ! command -v code &> /dev/null; then
    echo "Error: VS Code not found. Please install VS Code and try again."
    exit 1
fi

# Display script purpose
echo "VS Code Extension Extractor for Nix"
echo "==================================="
echo "This script extracts your installed VS Code extensions and formats them for use in Nix."
echo ""

# Get installed extensions
echo "Reading installed extensions..."
EXTENSIONS=$(code --list-extensions)

# Check for nixpkgs extensions
echo "Checking which extensions are available in nixpkgs..."
NIX_EXTENSIONS=$(nix-env -f '<nixpkgs>' -qaP -A vscode-extensions 2>/dev/null || echo "")

# Generate Nix configuration
echo "# VS Code extensions for Nix"
echo "# Add these to your extensions.nix file"
echo ""
echo "extensions = "
echo "  # Extensions available in nixpkgs (prefer these when available)"
echo "  (with pkgs.vscode-extensions; ["

# Process extensions for nixpkgs availability
for ext in $EXTENSIONS; do
    # Get publisher and name
    PUBLISHER=${ext%%.*}
    NAME=${ext#*.}
    
    # Check if extension is in nixpkgs
    if echo "$NIX_EXTENSIONS" | grep -q "$PUBLISHER.$NAME"; then
        echo "    $PUBLISHER.$NAME"
    else
        echo "    # $PUBLISHER.$NAME  # Not found in nixpkgs, use vscode-marketplace instead"
    fi
done

echo "  ])"
echo ""
echo "  # Extensions from VS Code Marketplace (for those not in nixpkgs)"
echo "  ++ (with pkgs.vscode-marketplace; ["

# Add marketplace format for extensions not in nixpkgs
for ext in $EXTENSIONS; do
    # Get publisher and name
    PUBLISHER=${ext%%.*}
    NAME=${ext#*.}
    
    # Check if extension is in nixpkgs
    if ! echo "$NIX_EXTENSIONS" | grep -q "$PUBLISHER.$NAME"; then
        echo "    $PUBLISHER.$NAME"
    fi
done

echo "  ]);"
echo ""
echo "# Note: This is a static snapshot of your extensions."
echo "# For a complete configuration, copy this to your extensions.nix file."
echo "# You may need to adjust category grouping and comments for better organization."
