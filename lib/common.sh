#!/bin/bash
#
# Common utility functions for Linux Setup System
#

# Portable installation path detection
get_install_root() {
    # Check for user-local installation first
    if [[ -f "$HOME/.local/share/linuxSetup/bin/setup-linux" ]]; then
        echo "$HOME/.local/share/linuxSetup"
    # Check for system-wide installation
    elif [[ -f "/opt/linuxSetup/bin/setup-linux" ]]; then
        echo "/opt/linuxSetup"
    # Check legacy location
    elif [[ -f "/srv/shared/Projects/linuxSetup/bin/setup-linux" ]]; then
        echo "/srv/shared/Projects/linuxSetup"
    # Fallback to script location
    else
        echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi
}

# Get user-writable log directory
get_log_directory() {
    local log_dir
    
    # Try user-specific directories first
    if [[ -n "${XDG_DATA_HOME:-}" ]]; then
        log_dir="$XDG_DATA_HOME/linuxSetup/logs"
    else
        log_dir="$HOME/.local/share/linuxSetup/logs"
    fi
    
    # Create directory if it doesn't exist and is writable
    if [[ ! -d "$log_dir" ]]; then
        if mkdir -p "$log_dir" 2>/dev/null; then
            echo "$log_dir"
            return 0
        fi
    elif [[ -w "$log_dir" ]]; then
        echo "$log_dir"
        return 0
    fi
    
    # Fallback to temp directory
    log_dir="/tmp/linuxSetup-$(whoami)"
    mkdir -p "$log_dir" 2>/dev/null || true
    echo "$log_dir"
}

# Get installation type
get_install_type() {
    local install_root
    install_root=$(get_install_root)
    
    if [[ "$install_root" == "$HOME/.local/share/linuxSetup" ]]; then
        echo "user"
    elif [[ "$install_root" == "/opt/linuxSetup" ]]; then
        echo "system"
    elif [[ "$install_root" == "/srv/shared/Projects/linuxSetup" ]]; then
        echo "legacy"
    else
        echo "portable"
    fi
}

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Function to check if user has sudo privileges
has_sudo() {
    sudo -n true 2>/dev/null
}

# Function to ensure sudo access
ensure_sudo() {
    if ! is_root && ! has_sudo; then
        echo -e "${RED}❌ This script requires sudo privileges${NC}"
        echo "Please run with sudo or ensure your user has sudo access"
        exit 1
    fi
}

# Function to print colored output
print_status() {
    local status="$1"
    local message="$2"
    
    case "$status" in
        "success"|"ok")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "error"|"fail")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "warning"|"warn")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "info")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
        "progress")
            echo -e "${CYAN}🔄 $message${NC}"
            ;;
        *)
            echo -e "${WHITE}$message${NC}"
            ;;
    esac
}

# Function to ask yes/no question
ask_yes_no() {
    local question="$1"
    local default="${2:-n}"
    
    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$question [Y/n]: " answer
            answer=${answer:-y}
        else
            read -p "$question [y/N]: " answer
            answer=${answer:-n}
        fi
        
        case "$answer" in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) echo "Please answer yes or no." ;;
        esac
    done
}

# Function to retry a command
retry_command() {
    local max_attempts="$1"
    local delay="$2"
    shift 2
    local command="$@"
    
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if eval "$command"; then
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            print_status "warning" "Command failed (attempt $attempt/$max_attempts), retrying in ${delay}s..."
            sleep "$delay"
        fi
        
        ((attempt++))
    done
    
    print_status "error" "Command failed after $max_attempts attempts"
    return 1
}

# Function to create directory with proper permissions
create_directory() {
    local dir="$1"
    local mode="${2:-755}"
    
    if [[ ! -d "$dir" ]]; then
        if mkdir -p "$dir" 2>/dev/null; then
            chmod "$mode" "$dir" 2>/dev/null || true
            print_status "success" "Created directory: $dir"
        else
            print_status "warning" "Could not create directory: $dir"
            return 1
        fi
    fi
}

# Function to backup file
backup_file() {
    local file="$1"
    local backup_dir="${2:-}"
    
    # Use default backup directory if not specified
    if [[ -z "$backup_dir" ]]; then
        backup_dir="$(get_log_directory)/config_backups"
    fi
    
    if [[ -f "$file" ]]; then
        if create_directory "$backup_dir"; then
            local backup_name="$(basename "$file").backup.$(date +%Y%m%d_%H%M%S)"
            if cp "$file" "$backup_dir/$backup_name" 2>/dev/null; then
                print_status "info" "Backed up $file to $backup_dir/$backup_name"
            else
                print_status "warning" "Could not backup $file"
            fi
        fi
    fi
}

# Function to get system architecture
get_architecture() {
    uname -m
}

# Function to get system hostname
get_hostname() {
    hostname
}

# Function to get system uptime
get_uptime() {
    uptime -p 2>/dev/null || uptime
}

# Function to get memory info
get_memory_info() {
    free -h | awk 'NR==2{printf "%.1fG used / %.1fG total", $3/1024, $2/1024}'
}

# Function to get disk info
get_disk_info() {
    df -h / | awk 'NR==2{printf "%s used / %s total (%s)", $3, $2, $5}'
}

# Function to validate IP address
validate_ip() {
    local ip="$1"
    local stat=1
    
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    
    return $stat
}

# Function to get primary IP address
get_primary_ip() {
    hostname -I | awk '{print $1}'
}

# Function to check internet connectivity
check_internet() {
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to download file with retries
download_file() {
    local url="$1"
    local output="$2"
    local max_attempts="${3:-3}"
    
    for ((i=1; i<=max_attempts; i++)); do
        if command_exists curl; then
            if curl -fsSL "$url" -o "$output"; then
                return 0
            fi
        elif command_exists wget; then
            if wget -q "$url" -O "$output"; then
                return 0
            fi
        else
            print_status "error" "Neither curl nor wget is available"
            return 1
        fi
        
        if [[ $i -lt $max_attempts ]]; then
            print_status "warning" "Download failed (attempt $i/$max_attempts), retrying..."
            sleep 2
        fi
    done
    
    return 1
}