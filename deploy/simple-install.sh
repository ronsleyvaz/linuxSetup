#!/bin/bash

# Simplified Universal Linux Setup & Monitoring System Installer
# Designed for maximum compatibility and minimal failure points

# Strict error handling
set -euo pipefail

# Installation metadata
readonly INSTALLER_VERSION="2.0.0"
readonly PROJECT_NAME="linuxSetup"
readonly GITHUB_REPO="https://github.com/user/linuxSetup.git"

# Installation types and default directories
readonly USER_DEFAULT_DIR="$HOME/.local/share/linuxSetup"
readonly SYSTEM_DEFAULT_DIR="/opt/linuxSetup"
readonly LEGACY_DEFAULT_DIR="/srv/shared/Projects/linuxSetup"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m' # No Color

# Print colored status messages
print_status() {
    local status="$1"
    local message="$2"
    
    case "$status" in
        "info")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
        "success")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "error")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "header")
            echo -e "${PURPLE}🚀 $message${NC}"
            ;;
    esac
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect operating system
detect_os() {
    local os_name
    os_name=$(uname -s)
    
    case "$os_name" in
        "Linux")
            echo "linux"
            ;;
        "Darwin")
            echo "macos"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Get preferred installation directory
get_install_directory() {
    local install_type="$1"
    
    case "$install_type" in
        "user")
            echo "$USER_DEFAULT_DIR"
            ;;
        "system")
            echo "$SYSTEM_DEFAULT_DIR"
            ;;
        "legacy")
            echo "$LEGACY_DEFAULT_DIR"
            ;;
        "portable")
            echo "$(pwd)/linuxSetup"
            ;;
        *)
            # Auto-detect best option
            if [[ -w "$HOME" ]]; then
                echo "$USER_DEFAULT_DIR"
            elif [[ -w "/opt" ]] || [[ $EUID -eq 0 ]]; then
                echo "$SYSTEM_DEFAULT_DIR"
            else
                echo "$(pwd)/linuxSetup"
            fi
            ;;
    esac
}

# Check if directory is writable or can be created
check_directory_writable() {
    local dir="$1"
    local parent_dir="$(dirname "$dir")"
    
    # If directory exists, check if writable
    if [[ -d "$dir" ]]; then
        [[ -w "$dir" ]]
        return $?
    fi
    
    # Check if parent directory is writable for creation
    if [[ -d "$parent_dir" ]]; then
        [[ -w "$parent_dir" ]]
        return $?
    fi
    
    # Check if we can create parent directories
    if mkdir -p "$parent_dir" 2>/dev/null; then
        rmdir "$parent_dir" 2>/dev/null || true
        return 0
    fi
    
    return 1
}

# Download project with multiple fallback methods
download_project() {
    local install_dir="$1"
    local method="${2:-auto}"
    
    print_status "info" "Downloading Linux Setup & Monitoring System..."
    
    # Try git clone first if available and requested
    if [[ "$method" == "git" || "$method" == "auto" ]] && command_exists git; then
        print_status "info" "Using git clone method..."
        if git clone "$GITHUB_REPO" "$install_dir" 2>/dev/null; then
            print_status "success" "Git clone successful"
            return 0
        else
            print_status "warning" "Git clone failed, trying alternative..."
        fi
    fi
    
    # Fallback to tarball download
    print_status "info" "Using tarball download method..."
    local temp_dir
    temp_dir=$(mktemp -d)
    local tarball_url="$GITHUB_REPO/archive/main.tar.gz"
    
    # Try curl first, then wget
    local download_success=false
    if command_exists curl; then
        if curl -fsSL "$tarball_url" -o "$temp_dir/linuxSetup.tar.gz"; then
            download_success=true
        fi
    elif command_exists wget; then
        if wget -q "$tarball_url" -O "$temp_dir/linuxSetup.tar.gz"; then
            download_success=true
        fi
    fi
    
    if [[ "$download_success" == false ]]; then
        print_status "error" "Failed to download project"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Create installation directory
    if ! mkdir -p "$install_dir"; then
        print_status "error" "Cannot create installation directory: $install_dir"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Extract tarball
    if tar -xzf "$temp_dir/linuxSetup.tar.gz" -C "$install_dir" --strip-components=1; then
        print_status "success" "Project downloaded successfully"
        rm -rf "$temp_dir"
        return 0
    else
        print_status "error" "Failed to extract project"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Set up minimal permissions
setup_basic_permissions() {
    local install_dir="$1"
    
    print_status "info" "Setting up basic permissions..."
    
    # Make scripts executable
    if [[ -d "$install_dir/bin" ]]; then
        find "$install_dir/bin" -type f -exec chmod +x {} \; 2>/dev/null || true
    fi
    
    if [[ -d "$install_dir/tests" ]]; then
        find "$install_dir/tests" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    fi
    
    # Create user-writable directories
    local log_dir
    if [[ -n "${XDG_DATA_HOME:-}" ]]; then
        log_dir="$XDG_DATA_HOME/linuxSetup/logs"
    else
        log_dir="$HOME/.local/share/linuxSetup/logs"
    fi
    
    mkdir -p "$log_dir" 2>/dev/null || true
    
    print_status "success" "Permissions configured"
    return 0
}

# Create simple PATH integration
setup_path_integration() {
    local install_dir="$1"
    local install_type="$2"
    
    print_status "info" "Setting up PATH integration..."
    
    # For user installations, add to shell profile
    if [[ "$install_type" == "user" ]]; then
        local shell_profile=""
        if [[ -n "${BASH_VERSION:-}" ]] && [[ -f "$HOME/.bashrc" ]]; then
            shell_profile="$HOME/.bashrc"
        elif [[ -n "${ZSH_VERSION:-}" ]] && [[ -f "$HOME/.zshrc" ]]; then
            shell_profile="$HOME/.zshrc"
        fi
        
        if [[ -n "$shell_profile" ]]; then
            local path_entry="export PATH=\"$install_dir/bin:\$PATH\""
            if ! grep -q "$install_dir/bin" "$shell_profile" 2>/dev/null; then
                echo "" >> "$shell_profile"
                echo "# Linux Setup & Monitoring System" >> "$shell_profile"
                echo "$path_entry" >> "$shell_profile"
                print_status "success" "Added to PATH in $shell_profile"
            fi
        fi
    fi
    
    # For system installations, try to create symlinks if possible
    if [[ "$install_type" == "system" ]] && [[ -w "/usr/local/bin" ]]; then
        local scripts=("setup-linux" "check-linux" "configure-linux" "setup-dev" "manage-users" "generate-report")
        local symlink_count=0
        
        for script in "${scripts[@]}"; do
            if [[ -f "$install_dir/bin/$script" ]]; then
                if ln -sf "$install_dir/bin/$script" "/usr/local/bin/$script" 2>/dev/null; then
                    ((symlink_count++))
                fi
            fi
        done
        
        if [[ $symlink_count -gt 0 ]]; then
            print_status "success" "Created $symlink_count command symlinks in /usr/local/bin"
        fi
    fi
    
    return 0
}

# Run initial verification
run_verification() {
    local install_dir="$1"
    
    print_status "info" "Running installation verification..."
    
    # Check if main script exists and is executable
    if [[ -x "$install_dir/bin/setup-linux" ]]; then
        # Try to run basic setup to verify installation
        if "$install_dir/bin/setup-linux" --help >/dev/null 2>&1; then
            print_status "success" "Installation verified successfully"
            return 0
        else
            print_status "warning" "Installation may have issues - check logs"
            return 1
        fi
    else
        print_status "error" "Main script not found or not executable"
        return 1
    fi
}

# Show installation summary
show_summary() {
    local install_dir="$1"
    local install_type="$2"
    local os_type="$3"
    
    print_status "header" "Installation Complete!"
    echo ""
    echo "📍 Installation Directory: $install_dir"
    echo "📦 Installation Type: $install_type"
    echo "🖥️  Operating System: $os_type"
    echo ""
    echo "🚀 Quick Start:"
    echo "  # Run system setup"
    echo "  $install_dir/bin/setup-linux"
    echo ""
    echo "  # Install essential tools"
    echo "  $install_dir/bin/setup-linux --install-tools"
    echo ""
    echo "  # Check system health"
    echo "  $install_dir/bin/check-linux"
    echo ""
    
    if [[ "$install_type" == "user" ]]; then
        echo "💡 Restart your terminal to use commands from PATH"
    fi
    
    echo "📖 Documentation: $install_dir/README.md"
    echo ""
    print_status "success" "Ready to use! 🎉"
}

# Show help
show_help() {
    cat << EOF
🚀 Simplified Universal Linux Setup & Monitoring System Installer v$INSTALLER_VERSION

USAGE:
    curl -fsSL [installer-url] | bash
    or
    $0 [INSTALL_TYPE] [OPTIONS]

INSTALL TYPES:
    user        Install in user directory (~/.local/share/linuxSetup) [DEFAULT]
    system      Install system-wide (/opt/linuxSetup) [requires sudo]
    legacy      Install in legacy location (/srv/shared/Projects/linuxSetup)
    portable    Install in current directory (./linuxSetup)

OPTIONS:
    --dir DIR           Custom installation directory
    --method METHOD     Download method: git or tarball (default: auto)
    --run-setup        Run initial setup after installation
    --help, -h          Show this help message

EXAMPLES:
    # User installation (recommended)
    $0 user

    # System-wide installation
    $0 system

    # Custom directory
    $0 user --dir ~/tools/linuxSetup

    # Portable installation with setup
    $0 portable --run-setup

SUPPORTED SYSTEMS:
    🐧 Linux: Ubuntu, Debian, CentOS, RHEL, Fedora, Arch, openSUSE, Alpine
    🍎 macOS: All recent versions

EOF
}

# Main installer function
main() {
    local install_type="user"
    local custom_dir=""
    local download_method="auto"
    local run_setup="false"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            user|system|legacy|portable)
                install_type="$1"
                shift
                ;;
            --dir)
                custom_dir="$2"
                shift 2
                ;;
            --method)
                download_method="$2"
                shift 2
                ;;
            --run-setup)
                run_setup="true"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Print header
    print_status "header" "Simplified Universal Linux Setup & Monitoring System Installer v$INSTALLER_VERSION"
    echo ""
    
    # Detect OS
    local os_type
    os_type=$(detect_os)
    
    if [[ "$os_type" == "unknown" ]]; then
        print_status "error" "Unsupported operating system"
        exit 1
    fi
    
    print_status "info" "Detected OS: $os_type"
    print_status "info" "Installation type: $install_type"
    
    # Determine installation directory
    local install_dir
    if [[ -n "$custom_dir" ]]; then
        install_dir="$custom_dir"
    else
        install_dir=$(get_install_directory "$install_type")
    fi
    
    print_status "info" "Installation directory: $install_dir"
    
    # Check directory writability
    if ! check_directory_writable "$install_dir"; then
        print_status "error" "Cannot write to installation directory: $install_dir"
        print_status "info" "Try a different installation type or directory"
        exit 1
    fi
    
    # Download project
    if ! download_project "$install_dir" "$download_method"; then
        print_status "error" "Failed to download project"
        exit 1
    fi
    
    # Set up basic permissions
    if ! setup_basic_permissions "$install_dir"; then
        print_status "error" "Failed to set up permissions"
        exit 1
    fi
    
    # Set up PATH integration
    setup_path_integration "$install_dir" "$install_type"
    
    # Run verification
    if ! run_verification "$install_dir"; then
        print_status "warning" "Installation verification had issues"
    fi
    
    # Run initial setup if requested
    if [[ "$run_setup" == "true" ]]; then
        print_status "info" "Running initial setup..."
        if "$install_dir/bin/setup-linux"; then
            print_status "success" "Initial setup completed"
        else
            print_status "warning" "Initial setup encountered issues"
        fi
    fi
    
    # Show summary
    show_summary "$install_dir" "$install_type" "$os_type"
    
    return 0
}

# Run main function with all arguments
main "$@"