#!/bin/bash

# Universal Linux Setup & Monitoring System Installer
# Cross-platform installation script for Linux and macOS

# Strict error handling
set -euo pipefail

# Installation metadata
readonly INSTALLER_VERSION="1.0.0"
readonly PROJECT_NAME="linuxSetup"
readonly GITHUB_REPO="https://github.com/user/linuxSetup.git"
readonly DEFAULT_INSTALL_DIR="/srv/shared/Projects/linuxSetup"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
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

# Detect Linux distribution
detect_linux_distro() {
    if [[ -f "/etc/os-release" ]]; then
        source /etc/os-release
        echo "${ID:-unknown}"
    elif command_exists lsb_release; then
        lsb_release -si | tr '[:upper:]' '[:lower:]'
    else
        echo "unknown"
    fi
}

# Check system prerequisites
check_prerequisites() {
    print_status "info" "Checking system prerequisites..."
    
    local os_type
    os_type=$(detect_os)
    
    # Check for bash version
    if [[ "${BASH_VERSION%%.*}" -lt 4 ]]; then
        print_status "error" "Bash 4.0+ required (current: $BASH_VERSION)"
        return 1
    fi
    
    # Check for required tools
    local required_tools=("curl" "tar")
    if [[ "$os_type" == "linux" ]]; then
        required_tools+=("sudo")
    fi
    
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            print_status "error" "Required tool not found: $tool"
            return 1
        fi
    done
    
    # Check for git (optional but recommended)
    if ! command_exists git; then
        print_status "warning" "Git not found - will use tarball download method"
    fi
    
    # Check disk space (require at least 1GB)
    local available_space
    if command_exists df; then
        available_space=$(df /tmp | tail -1 | awk '{print $4}')
        if [[ "$available_space" -lt 1048576 ]]; then  # 1GB in KB
            print_status "error" "Insufficient disk space (need at least 1GB)"
            return 1
        fi
    fi
    
    print_status "success" "Prerequisites check passed"
    return 0
}

# Download the project
download_project() {
    local install_dir="$1"
    local download_method="$2"
    
    print_status "info" "Downloading Linux Setup & Monitoring System..."
    
    # Create parent directory
    sudo mkdir -p "$(dirname "$install_dir")"
    
    case "$download_method" in
        "git")
            if command_exists git; then
                sudo git clone "$GITHUB_REPO" "$install_dir" || {
                    print_status "error" "Failed to clone repository"
                    return 1
                }
            else
                print_status "error" "Git not available for clone method"
                return 1
            fi
            ;;
        "tarball")
            local temp_dir
            temp_dir=$(mktemp -d)
            local tarball_url="$GITHUB_REPO/archive/main.tar.gz"
            
            # Download tarball
            curl -fsSL "$tarball_url" -o "$temp_dir/linuxSetup.tar.gz" || {
                print_status "error" "Failed to download tarball"
                rm -rf "$temp_dir"
                return 1
            }
            
            # Extract tarball
            sudo mkdir -p "$install_dir"
            sudo tar -xzf "$temp_dir/linuxSetup.tar.gz" -C "$install_dir" --strip-components=1 || {
                print_status "error" "Failed to extract tarball"
                rm -rf "$temp_dir"
                return 1
            }
            
            rm -rf "$temp_dir"
            ;;
        *)
            print_status "error" "Unknown download method: $download_method"
            return 1
            ;;
    esac
    
    print_status "success" "Project downloaded to: $install_dir"
    return 0
}

# Set up permissions and ownership
setup_permissions() {
    local install_dir="$1"
    
    print_status "info" "Setting up permissions..."
    
    # Make scripts executable
    sudo find "$install_dir/bin" -type f -exec chmod +x {} \; 2>/dev/null || true
    sudo find "$install_dir/tests" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    
    # Create logs directory
    sudo mkdir -p "$install_dir/logs"
    sudo mkdir -p "$install_dir/reports"
    
    # Set ownership to current user if not root
    if [[ $EUID -ne 0 ]]; then
        local current_user
        current_user=$(whoami)
        sudo chown -R "$current_user:$current_user" "$install_dir" 2>/dev/null || {
            print_status "warning" "Could not change ownership to $current_user"
        }
    fi
    
    print_status "success" "Permissions configured"
    return 0
}

# Install system dependencies
install_dependencies() {
    local os_type="$1"
    
    print_status "info" "Installing system dependencies..."
    
    case "$os_type" in
        "linux")
            local distro
            distro=$(detect_linux_distro)
            
            case "$distro" in
                "ubuntu"|"debian")
                    sudo apt update
                    sudo apt install -y curl wget git vim build-essential
                    ;;
                "centos"|"rhel"|"fedora")
                    if command_exists dnf; then
                        sudo dnf install -y curl wget git vim gcc gcc-c++ make
                    elif command_exists yum; then
                        sudo yum install -y curl wget git vim gcc gcc-c++ make
                    fi
                    ;;
                "arch"|"manjaro")
                    sudo pacman -Sy --noconfirm curl wget git vim base-devel
                    ;;
                *)
                    print_status "warning" "Unknown Linux distribution: $distro"
                    print_status "info" "Skipping automatic dependency installation"
                    ;;
            esac
            ;;
        "macos")
            # Check for Homebrew and install if needed
            if ! command_exists brew; then
                print_status "info" "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                
                # Add Homebrew to PATH
                if [[ -f "/opt/homebrew/bin/brew" ]]; then
                    export PATH="/opt/homebrew/bin:$PATH"
                elif [[ -f "/usr/local/bin/brew" ]]; then
                    export PATH="/usr/local/bin:$PATH"
                fi
            fi
            
            # Install basic tools
            brew install curl wget git vim gcc
            ;;
    esac
    
    print_status "success" "Dependencies installed"
    return 0
}

# Create shell integration
create_shell_integration() {
    local install_dir="$1"
    
    print_status "info" "Setting up shell integration..."
    
    # Create symlinks for easy access
    local bin_dir="/usr/local/bin"
    if [[ -w "$bin_dir" ]] || sudo test -w "$bin_dir"; then
        local scripts=("setup-linux" "check-linux" "configure-linux" "setup-dev" "manage-users" "generate-report")
        
        for script in "${scripts[@]}"; do
            if [[ -f "$install_dir/bin/$script" ]]; then
                sudo ln -sf "$install_dir/bin/$script" "$bin_dir/$script" 2>/dev/null || {
                    print_status "warning" "Could not create symlink for $script"
                }
            fi
        done
    else
        print_status "warning" "Cannot create symlinks in $bin_dir - scripts available in $install_dir/bin/"
    fi
    
    # Add to PATH in shell profile
    local shell_profile=""
    if [[ -n "${BASH_VERSION:-}" ]]; then
        shell_profile="$HOME/.bashrc"
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        shell_profile="$HOME/.zshrc"
    fi
    
    if [[ -n "$shell_profile" && -f "$shell_profile" ]]; then
        local path_entry="export PATH=\"$install_dir/bin:\$PATH\""
        if ! grep -q "$install_dir/bin" "$shell_profile"; then
            echo "" >> "$shell_profile"
            echo "# Linux Setup & Monitoring System" >> "$shell_profile"
            echo "$path_entry" >> "$shell_profile"
            print_status "success" "Added to shell PATH in $shell_profile"
        fi
    fi
    
    return 0
}

# Run initial setup
run_initial_setup() {
    local install_dir="$1"
    local auto_setup="$2"
    
    if [[ "$auto_setup" == "true" ]]; then
        print_status "info" "Running initial system setup..."
        
        # Run basic setup
        if [[ -x "$install_dir/bin/setup-linux" ]]; then
            "$install_dir/bin/setup-linux" || {
                print_status "warning" "Initial setup encountered issues - check logs"
            }
        fi
        
        print_status "success" "Initial setup completed"
    else
        print_status "info" "Skipping automatic setup - run manually with:"
        echo "  $install_dir/bin/setup-linux"
    fi
    
    return 0
}

# Show installation summary
show_summary() {
    local install_dir="$1"
    local os_type="$2"
    
    print_status "header" "Installation Complete!"
    echo ""
    echo "📍 Installation Directory: $install_dir"
    echo "🖥️  Operating System: $os_type"
    echo ""
    echo "🚀 Available Commands:"
    echo "  setup-linux      - Complete system setup and tool installation"
    echo "  check-linux      - System health monitoring and status"
    echo "  configure-linux  - Service configuration (SSH, firewall, etc.)"
    echo "  setup-dev        - Development environment setup"
    echo "  manage-users     - User and permission management"
    echo "  generate-report  - System analysis and reporting"
    echo ""
    echo "📚 Quick Start:"
    echo "  1. Run: setup-linux --install-tools"
    echo "  2. Check status: check-linux"
    echo "  3. Configure services: configure-linux"
    echo ""
    echo "📖 Documentation: $install_dir/README.md"
    echo "📝 Logs Directory: $install_dir/logs/"
    echo ""
    print_status "success" "Ready to use! 🎉"
}

# Show help
show_help() {
    cat << EOF
🚀 Universal Linux Setup & Monitoring System Installer v$INSTALLER_VERSION

USAGE:
    curl -fsSL [installer-url] | bash
    or
    $0 [OPTIONS]

OPTIONS:
    --dir DIR           Installation directory (default: $DEFAULT_INSTALL_DIR)
    --method METHOD     Download method: git or tarball (default: auto-detect)
    --auto-setup        Run initial setup automatically after installation
    --no-deps           Skip dependency installation
    --help, -h          Show this help message

EXAMPLES:
    # Basic installation
    $0

    # Custom directory
    $0 --dir /opt/linuxSetup

    # Use tarball method (no git required)
    $0 --method tarball --auto-setup

    # Skip dependency installation
    $0 --no-deps

SUPPORTED SYSTEMS:
    🐧 Linux: Ubuntu, Debian, CentOS, RHEL, Fedora, Arch, openSUSE, Alpine
    🍎 macOS: All recent versions with Homebrew support

FEATURES:
    ✅ Multi-distribution Linux support
    ✅ macOS support with Homebrew
    ✅ Essential tools installation (24+ tools)
    ✅ System health monitoring
    ✅ Service configuration (SSH, firewall, NTP)
    ✅ Development environment setup
    ✅ User and permission management
    ✅ Comprehensive reporting
    ✅ Cross-platform compatibility

EOF
}

# Main installer function
main() {
    # Parse command line arguments
    local install_dir="$DEFAULT_INSTALL_DIR"
    local download_method="auto"
    local auto_setup="false"
    local install_deps="true"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dir)
                install_dir="$2"
                shift 2
                ;;
            --method)
                download_method="$2"
                shift 2
                ;;
            --auto-setup)
                auto_setup="true"
                shift
                ;;
            --no-deps)
                install_deps="false"
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
    print_status "header" "Universal Linux Setup & Monitoring System Installer v$INSTALLER_VERSION"
    echo ""
    
    # Detect OS
    local os_type
    os_type=$(detect_os)
    
    if [[ "$os_type" == "unknown" ]]; then
        print_status "error" "Unsupported operating system"
        exit 1
    fi
    
    print_status "info" "Detected OS: $os_type"
    
    if [[ "$os_type" == "linux" ]]; then
        local distro
        distro=$(detect_linux_distro)
        print_status "info" "Linux distribution: $distro"
    fi
    
    # Check prerequisites
    if ! check_prerequisites; then
        print_status "error" "Prerequisites check failed"
        exit 1
    fi
    
    # Auto-detect download method
    if [[ "$download_method" == "auto" ]]; then
        if command_exists git; then
            download_method="git"
        else
            download_method="tarball"
        fi
    fi
    
    print_status "info" "Using download method: $download_method"
    print_status "info" "Installation directory: $install_dir"
    
    # Install dependencies
    if [[ "$install_deps" == "true" ]]; then
        install_dependencies "$os_type"
    else
        print_status "info" "Skipping dependency installation"
    fi
    
    # Download project
    if ! download_project "$install_dir" "$download_method"; then
        print_status "error" "Failed to download project"
        exit 1
    fi
    
    # Set up permissions
    if ! setup_permissions "$install_dir"; then
        print_status "error" "Failed to set up permissions"
        exit 1
    fi
    
    # Create shell integration
    create_shell_integration "$install_dir"
    
    # Run initial setup
    run_initial_setup "$install_dir" "$auto_setup"
    
    # Show summary
    show_summary "$install_dir" "$os_type"
    
    return 0
}

# Run main function with all arguments
main "$@"