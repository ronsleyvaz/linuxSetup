#!/bin/bash
#
# Distribution Detection System for Linux Setup
# Detects Linux distribution and sets global variables
#

# Global variables for distribution information
DISTRO_ID=""
DISTRO_NAME=""
DISTRO_VERSION=""
DISTRO_CODENAME=""
DISTRO_FAMILY=""
DISTRO_ARCHITECTURE=""

# Function to detect distribution using /etc/os-release
detect_from_os_release() {
    local os_release_file="/etc/os-release"
    
    if [[ -f "$os_release_file" ]]; then
        log_debug "Reading distribution info from $os_release_file"
        
        # Source the file to get variables
        source "$os_release_file" 2>/dev/null || return 1
        
        # Set global variables
        DISTRO_ID="${ID:-unknown}"
        DISTRO_NAME="${NAME:-unknown}"
        DISTRO_VERSION="${VERSION_ID:-unknown}"
        DISTRO_CODENAME="${VERSION_CODENAME:-unknown}"
        
        log_debug "From os-release: ID=$DISTRO_ID, NAME=$DISTRO_NAME, VERSION=$DISTRO_VERSION"
        return 0
    fi
    
    return 1
}

# Function to detect distribution using lsb_release
detect_from_lsb_release() {
    if command_exists lsb_release; then
        log_debug "Using lsb_release for distribution detection"
        
        DISTRO_ID=$(lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]')
        DISTRO_NAME=$(lsb_release -sd 2>/dev/null | tr -d '"')
        DISTRO_VERSION=$(lsb_release -sr 2>/dev/null)
        DISTRO_CODENAME=$(lsb_release -sc 2>/dev/null)
        
        log_debug "From lsb_release: ID=$DISTRO_ID, NAME=$DISTRO_NAME, VERSION=$DISTRO_VERSION"
        return 0
    fi
    
    return 1
}

# Function to detect distribution from release files
detect_from_release_files() {
    local release_file=""
    
    # Check various release files
    if [[ -f "/etc/redhat-release" ]]; then
        release_file="/etc/redhat-release"
        DISTRO_FAMILY="redhat"
    elif [[ -f "/etc/debian_version" ]]; then
        release_file="/etc/debian_version"
        DISTRO_FAMILY="debian"
    elif [[ -f "/etc/arch-release" ]]; then
        release_file="/etc/arch-release"
        DISTRO_FAMILY="arch"
    elif [[ -f "/etc/suse-release" ]]; then
        release_file="/etc/suse-release"
        DISTRO_FAMILY="suse"
    elif [[ -f "/etc/alpine-release" ]]; then
        release_file="/etc/alpine-release"
        DISTRO_FAMILY="alpine"
    fi
    
    if [[ -n "$release_file" ]]; then
        log_debug "Found release file: $release_file"
        
        # Parse specific release files
        case "$release_file" in
            "/etc/redhat-release")
                parse_redhat_release
                ;;
            "/etc/debian_version")
                parse_debian_version
                ;;
            "/etc/arch-release")
                parse_arch_release
                ;;
            "/etc/suse-release")
                parse_suse_release
                ;;
            "/etc/alpine-release")
                parse_alpine_release
                ;;
        esac
        
        return 0
    fi
    
    return 1
}

# Function to parse RedHat-style release files
parse_redhat_release() {
    local content=$(cat /etc/redhat-release)
    
    if [[ "$content" =~ CentOS ]]; then
        DISTRO_ID="centos"
        DISTRO_NAME="CentOS"
    elif [[ "$content" =~ "Red Hat Enterprise Linux" ]]; then
        DISTRO_ID="rhel"
        DISTRO_NAME="Red Hat Enterprise Linux"
    elif [[ "$content" =~ Fedora ]]; then
        DISTRO_ID="fedora"
        DISTRO_NAME="Fedora"
    elif [[ "$content" =~ "Amazon Linux" ]]; then
        DISTRO_ID="amzn"
        DISTRO_NAME="Amazon Linux"
    fi
    
    # Extract version
    if [[ "$content" =~ ([0-9]+\.[0-9]+) ]]; then
        DISTRO_VERSION="${BASH_REMATCH[1]}"
    elif [[ "$content" =~ ([0-9]+) ]]; then
        DISTRO_VERSION="${BASH_REMATCH[1]}"
    fi
    
    DISTRO_FAMILY="redhat"
}

# Function to parse Debian version
parse_debian_version() {
    DISTRO_VERSION=$(cat /etc/debian_version)
    
    # Check if it's Ubuntu (has additional files)
    if [[ -f "/etc/lsb-release" ]]; then
        source /etc/lsb-release 2>/dev/null
        if [[ "$DISTRIB_ID" == "Ubuntu" ]]; then
            DISTRO_ID="ubuntu"
            DISTRO_NAME="Ubuntu"
            DISTRO_VERSION="$DISTRIB_RELEASE"
            DISTRO_CODENAME="$DISTRIB_CODENAME"
        fi
    else
        DISTRO_ID="debian"
        DISTRO_NAME="Debian"
    fi
    
    DISTRO_FAMILY="debian"
}

# Function to parse Arch release
parse_arch_release() {
    DISTRO_ID="arch"
    DISTRO_NAME="Arch Linux"
    DISTRO_VERSION="rolling"
    DISTRO_FAMILY="arch"
}

# Function to parse SUSE release
parse_suse_release() {
    local content=$(cat /etc/suse-release)
    
    if [[ "$content" =~ openSUSE ]]; then
        DISTRO_ID="opensuse"
        DISTRO_NAME="openSUSE"
    else
        DISTRO_ID="suse"
        DISTRO_NAME="SUSE Linux"
    fi
    
    # Extract version
    if [[ "$content" =~ VERSION\ =\ ([0-9]+\.[0-9]+) ]]; then
        DISTRO_VERSION="${BASH_REMATCH[1]}"
    fi
    
    DISTRO_FAMILY="suse"
}

# Function to parse Alpine release
parse_alpine_release() {
    DISTRO_ID="alpine"
    DISTRO_NAME="Alpine Linux"
    DISTRO_VERSION=$(cat /etc/alpine-release)
    DISTRO_FAMILY="alpine"
}

# Function to detect architecture
detect_architecture() {
    DISTRO_ARCHITECTURE=$(uname -m)
    
    # Normalize architecture names
    case "$DISTRO_ARCHITECTURE" in
        "x86_64"|"amd64")
            DISTRO_ARCHITECTURE="x86_64"
            ;;
        "i386"|"i686")
            DISTRO_ARCHITECTURE="i386"
            ;;
        "aarch64"|"arm64")
            DISTRO_ARCHITECTURE="arm64"
            ;;
        "armv7l"|"armhf")
            DISTRO_ARCHITECTURE="armhf"
            ;;
    esac
    
    log_debug "Architecture: $DISTRO_ARCHITECTURE"
}

# Function to determine distribution family if not set
determine_family() {
    if [[ -z "$DISTRO_FAMILY" ]]; then
        case "$DISTRO_ID" in
            "ubuntu"|"debian"|"raspbian"|"linuxmint"|"pop")
                DISTRO_FAMILY="debian"
                ;;
            "centos"|"rhel"|"fedora"|"amzn"|"rocky"|"almalinux")
                DISTRO_FAMILY="redhat"
                ;;
            "arch"|"manjaro"|"endeavouros")
                DISTRO_FAMILY="arch"
                ;;
            "opensuse"|"sles")
                DISTRO_FAMILY="suse"
                ;;
            "alpine")
                DISTRO_FAMILY="alpine"
                ;;
            *)
                DISTRO_FAMILY="unknown"
                ;;
        esac
    fi
    
    log_debug "Distribution family: $DISTRO_FAMILY"
}

# Function to validate detection results
validate_detection() {
    if [[ -z "$DISTRO_ID" || "$DISTRO_ID" == "unknown" ]]; then
        log_error "Failed to detect distribution ID"
        return 1
    fi
    
    if [[ -z "$DISTRO_NAME" || "$DISTRO_NAME" == "unknown" ]]; then
        log_warn "Distribution name not detected, using ID: $DISTRO_ID"
        DISTRO_NAME="$DISTRO_ID"
    fi
    
    if [[ -z "$DISTRO_VERSION" || "$DISTRO_VERSION" == "unknown" ]]; then
        log_warn "Distribution version not detected"
        DISTRO_VERSION="unknown"
    fi
    
    if [[ -z "$DISTRO_FAMILY" || "$DISTRO_FAMILY" == "unknown" ]]; then
        log_warn "Could not determine distribution family"
        return 1
    fi
    
    return 0
}

# Function to check if distribution is supported
is_supported_distribution() {
    case "$DISTRO_FAMILY" in
        "debian"|"redhat"|"arch"|"suse"|"alpine"|"darwin")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to get distribution support level
get_support_level() {
    case "$DISTRO_ID" in
        "ubuntu"|"debian"|"centos"|"rhel"|"fedora"|"macos")
            echo "full"
            ;;
        "arch"|"opensuse"|"amzn"|"rocky"|"almalinux")
            echo "partial"
            ;;
        "alpine"|"manjaro"|"pop"|"linuxmint")
            echo "experimental"
            ;;
        *)
            echo "unsupported"
            ;;
    esac
}

# Function to detect macOS
detect_macos() {
    log_debug "Detecting macOS system"
    
    # Get macOS version
    local macos_version
    macos_version=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
    
    # Get macOS build
    local macos_build
    macos_build=$(sw_vers -buildVersion 2>/dev/null || echo "unknown")
    
    # Get macOS codename based on version
    local macos_codename
    case "${macos_version%%.*}" in
        "14") macos_codename="Sonoma" ;;
        "13") macos_codename="Ventura" ;;
        "12") macos_codename="Monterey" ;;
        "11") macos_codename="Big Sur" ;;
        "10")
            case "${macos_version%.*}" in
                "10.15") macos_codename="Catalina" ;;
                "10.14") macos_codename="Mojave" ;;
                "10.13") macos_codename="High Sierra" ;;
                *) macos_codename="macOS" ;;
            esac
            ;;
        *) macos_codename="macOS" ;;
    esac
    
    # Set global variables
    DISTRO_ID="macos"
    DISTRO_NAME="macOS"
    DISTRO_VERSION="$macos_version"
    DISTRO_CODENAME="$macos_codename"
    DISTRO_FAMILY="darwin"
    DISTRO_ARCHITECTURE=$(uname -m)
    
    log_info "Detected macOS $macos_version ($macos_codename) on $DISTRO_ARCHITECTURE"
    return 0
}

# Main distribution detection function
detect_distribution() {
    log_function_enter "detect_distribution"
    
    # Reset global variables
    DISTRO_ID=""
    DISTRO_NAME=""
    DISTRO_VERSION=""
    DISTRO_CODENAME=""
    DISTRO_FAMILY=""
    DISTRO_ARCHITECTURE=""
    
    # Check if running on macOS first
    if [[ "$(uname -s)" == "Darwin" ]]; then
        detect_macos
        return 0
    fi
    
    # Try detection methods in order of preference (Linux)
    local detection_success=false
    
    # Method 1: /etc/os-release (most reliable)
    if detect_from_os_release; then
        detection_success=true
        log_debug "Distribution detected using /etc/os-release"
    fi
    
    # Method 2: lsb_release command
    if [[ "$detection_success" == false ]] && detect_from_lsb_release; then
        detection_success=true
        log_debug "Distribution detected using lsb_release"
    fi
    
    # Method 3: Release files
    if [[ "$detection_success" == false ]] && detect_from_release_files; then
        detection_success=true
        log_debug "Distribution detected using release files"
    fi
    
    # Detect architecture
    detect_architecture
    
    # Determine family if not set
    determine_family
    
    # Validate results
    if ! validate_detection; then
        log_error "Distribution detection validation failed"
        log_function_exit "detect_distribution" 1
        return 1
    fi
    
    # Check support level
    local support_level=$(get_support_level)
    log_info "Distribution support level: $support_level"
    
    if [[ "$support_level" == "unsupported" ]]; then
        log_warn "Distribution $DISTRO_ID is not officially supported"
        log_warn "The setup may not work correctly"
    fi
    
    # Log final results
    log_info "Distribution detection complete:"
    log_info "  ID: $DISTRO_ID"
    log_info "  Name: $DISTRO_NAME"
    log_info "  Version: $DISTRO_VERSION"
    log_info "  Codename: $DISTRO_CODENAME"
    log_info "  Family: $DISTRO_FAMILY"
    log_info "  Architecture: $DISTRO_ARCHITECTURE"
    log_info "  Support Level: $support_level"
    
    log_function_exit "detect_distribution" 0
    return 0
}

# Function to print distribution information
print_distribution_info() {
    echo "Distribution Information:"
    echo "  ID: $DISTRO_ID"
    echo "  Name: $DISTRO_NAME"
    echo "  Version: $DISTRO_VERSION"
    echo "  Codename: $DISTRO_CODENAME"
    echo "  Family: $DISTRO_FAMILY"
    echo "  Architecture: $DISTRO_ARCHITECTURE"
    echo "  Support Level: $(get_support_level)"
}

# Function to export distribution variables for use in other scripts
export_distribution_vars() {
    export DISTRO_ID
    export DISTRO_NAME
    export DISTRO_VERSION
    export DISTRO_CODENAME
    export DISTRO_FAMILY
    export DISTRO_ARCHITECTURE
}