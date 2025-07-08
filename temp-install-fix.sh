#!/bin/bash

# Temporary installer with direct download - bypasses GitHub cache issues
set -euo pipefail

# Direct download and install
echo "🚀 Installing linuxSetup directly..."

# Create user directory
INSTALL_DIR="$HOME/.local/share/linuxSetup"
mkdir -p "$INSTALL_DIR"

# Download tarball directly
echo "📦 Downloading from GitHub..."
curl -fsSL "https://github.com/ronsleyvaz/linuxSetup/archive/main.tar.gz" | tar -xz -C "$INSTALL_DIR" --strip-components=1

# Set permissions
chmod +x "$INSTALL_DIR/bin/"*
find "$INSTALL_DIR/tests" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# Create logs directory
mkdir -p "$HOME/.local/share/linuxSetup/logs"

# Add to PATH
SHELL_PROFILE=""
if [[ -n "${BASH_VERSION:-}" ]] && [[ -f "$HOME/.bashrc" ]]; then
    SHELL_PROFILE="$HOME/.bashrc"
elif [[ -n "${ZSH_VERSION:-}" ]] && [[ -f "$HOME/.zshrc" ]]; then
    SHELL_PROFILE="$HOME/.zshrc"
fi

if [[ -n "$SHELL_PROFILE" ]]; then
    if ! grep -q "$INSTALL_DIR/bin" "$SHELL_PROFILE" 2>/dev/null; then
        echo "" >> "$SHELL_PROFILE"
        echo "# Linux Setup & Monitoring System" >> "$SHELL_PROFILE"
        echo "export PATH=\"$INSTALL_DIR/bin:\$PATH\"" >> "$SHELL_PROFILE"
        echo "✅ Added to PATH in $SHELL_PROFILE"
    fi
fi

echo ""
echo "🎉 Installation Complete!"
echo "📍 Installed in: $INSTALL_DIR"
echo ""
echo "🚀 Quick start:"
echo "  $INSTALL_DIR/bin/setup-linux"
echo "  $INSTALL_DIR/bin/setup-linux --install-tools"
echo "  $INSTALL_DIR/bin/check-linux"
echo ""
echo "💡 Restart your terminal to use commands from PATH"