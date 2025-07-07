#!/bin/bash
#
# Package Manager Abstraction Layer for Linux Setup
# Provides unified interface for different package managers
#

# Global variables for package manager
PACKAGE_MANAGER=""
PACKAGE_MANAGER_CMD=""
PACKAGE_MANAGER_INSTALL_CMD=""
PACKAGE_MANAGER_UPDATE_CMD=""
PACKAGE_MANAGER_SEARCH_CMD=""
PACKAGE_MANAGER_REMOVE_CMD=""

# Function to detect package manager based on distribution
detect_package_manager() {
    log_function_enter "detect_package_manager"
    
    case "$DISTRO_FAMILY" in
        "debian")
            if command_exists apt; then
                PACKAGE_MANAGER="apt"
                PACKAGE_MANAGER_CMD="apt"
            elif command_exists apt-get; then
                PACKAGE_MANAGER="apt-get"
                PACKAGE_MANAGER_CMD="apt-get"
            else
                log_error "No APT package manager found"
                return 1
            fi
            ;;
        "redhat")
            if command_exists dnf; then
                PACKAGE_MANAGER="dnf"
                PACKAGE_MANAGER_CMD="dnf"
            elif command_exists yum; then
                PACKAGE_MANAGER="yum"
                PACKAGE_MANAGER_CMD="yum"
            else
                log_error "No YUM/DNF package manager found"
                return 1
            fi
            ;;
        "arch")
            if command_exists pacman; then
                PACKAGE_MANAGER="pacman"
                PACKAGE_MANAGER_CMD="pacman"
            else
                log_error "No Pacman package manager found"
                return 1
            fi
            ;;
        "suse")
            if command_exists zypper; then
                PACKAGE_MANAGER="zypper"
                PACKAGE_MANAGER_CMD="zypper"
            else
                log_error "No Zypper package manager found"
                return 1
            fi
            ;;
        "alpine")
            if command_exists apk; then
                PACKAGE_MANAGER="apk"
                PACKAGE_MANAGER_CMD="apk"
            else
                log_error "No APK package manager found"
                return 1
            fi
            ;;
        "darwin")
            if command_exists brew; then
                PACKAGE_MANAGER="brew"
                PACKAGE_MANAGER_CMD="brew"
            else
                log_warn "Homebrew not found on macOS, installation will be attempted"
                PACKAGE_MANAGER="brew"
                PACKAGE_MANAGER_CMD="brew"
            fi
            ;;
        *)
            log_error "Unsupported distribution family: $DISTRO_FAMILY"
            return 1
            ;;
    esac
    
    log_info "Detected package manager: $PACKAGE_MANAGER"
    log_function_exit "detect_package_manager" 0
    return 0
}

# Function to set package manager commands
set_package_manager_commands() {
    log_function_enter "set_package_manager_commands"
    
    case "$PACKAGE_MANAGER" in
        "apt")
            PACKAGE_MANAGER_INSTALL_CMD="apt install -y"
            PACKAGE_MANAGER_UPDATE_CMD="apt update"
            PACKAGE_MANAGER_SEARCH_CMD="apt search"
            PACKAGE_MANAGER_REMOVE_CMD="apt remove -y"
            ;;
        "apt-get")
            PACKAGE_MANAGER_INSTALL_CMD="apt-get install -y"
            PACKAGE_MANAGER_UPDATE_CMD="apt-get update"
            PACKAGE_MANAGER_SEARCH_CMD="apt-cache search"
            PACKAGE_MANAGER_REMOVE_CMD="apt-get remove -y"
            ;;
        "dnf")
            PACKAGE_MANAGER_INSTALL_CMD="dnf install -y"
            PACKAGE_MANAGER_UPDATE_CMD="dnf makecache"
            PACKAGE_MANAGER_SEARCH_CMD="dnf search"
            PACKAGE_MANAGER_REMOVE_CMD="dnf remove -y"
            ;;
        "yum")
            PACKAGE_MANAGER_INSTALL_CMD="yum install -y"
            PACKAGE_MANAGER_UPDATE_CMD="yum makecache"
            PACKAGE_MANAGER_SEARCH_CMD="yum search"
            PACKAGE_MANAGER_REMOVE_CMD="yum remove -y"
            ;;
        "pacman")
            PACKAGE_MANAGER_INSTALL_CMD="pacman -S --noconfirm"
            PACKAGE_MANAGER_UPDATE_CMD="pacman -Sy"
            PACKAGE_MANAGER_SEARCH_CMD="pacman -Ss"
            PACKAGE_MANAGER_REMOVE_CMD="pacman -R --noconfirm"
            ;;
        "zypper")
            PACKAGE_MANAGER_INSTALL_CMD="zypper install -y"
            PACKAGE_MANAGER_UPDATE_CMD="zypper refresh"
            PACKAGE_MANAGER_SEARCH_CMD="zypper search"
            PACKAGE_MANAGER_REMOVE_CMD="zypper remove -y"
            ;;
        "apk")
            PACKAGE_MANAGER_INSTALL_CMD="apk add"
            PACKAGE_MANAGER_UPDATE_CMD="apk update"
            PACKAGE_MANAGER_SEARCH_CMD="apk search"
            PACKAGE_MANAGER_REMOVE_CMD="apk del"
            ;;
        "brew")
            PACKAGE_MANAGER_INSTALL_CMD="brew install"
            PACKAGE_MANAGER_UPDATE_CMD="brew update"
            PACKAGE_MANAGER_SEARCH_CMD="brew search"
            PACKAGE_MANAGER_REMOVE_CMD="brew uninstall"
            ;;
        *)
            log_error "Unknown package manager: $PACKAGE_MANAGER"
            return 1
            ;;
    esac
    
    log_debug "Package manager commands set:"
    log_debug "  Install: $PACKAGE_MANAGER_INSTALL_CMD"
    log_debug "  Update: $PACKAGE_MANAGER_UPDATE_CMD"
    log_debug "  Search: $PACKAGE_MANAGER_SEARCH_CMD"
    log_debug "  Remove: $PACKAGE_MANAGER_REMOVE_CMD"
    
    log_function_exit "set_package_manager_commands" 0
    return 0
}

# Function to initialize package manager
init_package_manager() {
    log_function_enter "init_package_manager"
    
    # Detect package manager
    if ! detect_package_manager; then
        log_error "Failed to detect package manager"
        return 1
    fi
    
    # Set commands
    if ! set_package_manager_commands; then
        log_error "Failed to set package manager commands"
        return 1
    fi
    
    log_info "Package manager initialized: $PACKAGE_MANAGER"
    log_function_exit "init_package_manager" 0
    return 0
}

# Function to update package lists
update_package_lists() {
    log_function_enter "update_package_lists"
    
    print_status "progress" "Updating package lists..."
    
    if log_command "sudo $PACKAGE_MANAGER_UPDATE_CMD" "Update package lists"; then
        print_status "success" "Package lists updated"
        log_function_exit "update_package_lists" 0
        return 0
    else
        print_status "error" "Failed to update package lists"
        log_function_exit "update_package_lists" 1
        return 1
    fi
}

# Function to install a single package
install_package() {
    local package="$1"
    local description="${2:-Installing $package}"
    
    log_function_enter "install_package"
    log_info "Installing package: $package"
    
    print_status "progress" "$description..."
    
    if log_command "sudo $PACKAGE_MANAGER_INSTALL_CMD $package" "Install package: $package"; then
        print_status "success" "$description completed"
        log_function_exit "install_package" 0
        return 0
    else
        print_status "error" "$description failed"
        log_function_exit "install_package" 1
        return 1
    fi
}

# Function to install multiple packages
install_packages() {
    local packages=("$@")
    local failed_packages=()
    local success_count=0
    local total_count=${#packages[@]}
    
    log_function_enter "install_packages"
    log_info "Installing $total_count packages: ${packages[*]}"
    
    print_status "progress" "Installing $total_count packages..."
    
    for package in "${packages[@]}"; do
        if install_package "$package" "Installing $package"; then
            ((success_count++))
        else
            failed_packages+=("$package")
        fi
    done
    
    log_info "Package installation complete: $success_count/$total_count successful"
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        print_status "warning" "Failed to install ${#failed_packages[@]} packages: ${failed_packages[*]}"
        log_warn "Failed packages: ${failed_packages[*]}"
    fi
    
    if [[ $success_count -gt 0 ]]; then
        print_status "success" "Successfully installed $success_count/$total_count packages"
    fi
    
    log_function_exit "install_packages" 0
    return 0
}

# Function to install packages in batches
install_packages_batch() {
    local batch_size="${1:-10}"
    shift
    local packages=("$@")
    local total_count=${#packages[@]}
    
    log_function_enter "install_packages_batch"
    log_info "Installing $total_count packages in batches of $batch_size"
    
    # Split packages into batches
    local batch_start=0
    local batch_num=1
    
    while [[ $batch_start -lt $total_count ]]; do
        local batch_end=$((batch_start + batch_size))
        if [[ $batch_end -gt $total_count ]]; then
            batch_end=$total_count
        fi
        
        local batch_packages=("${packages[@]:$batch_start:$batch_size}")
        local batch_count=${#batch_packages[@]}
        
        print_status "progress" "Installing batch $batch_num ($batch_count packages)..."
        log_info "Batch $batch_num: ${batch_packages[*]}"
        
        # Create batch command
        local batch_command="sudo $PACKAGE_MANAGER_INSTALL_CMD ${batch_packages[*]}"
        
        if log_command "$batch_command" "Install batch $batch_num"; then
            print_status "success" "Batch $batch_num completed"
        else
            print_status "warning" "Batch $batch_num had issues, trying individual installs..."
            install_packages "${batch_packages[@]}"
        fi
        
        batch_start=$batch_end
        ((batch_num++))
    done
    
    log_function_exit "install_packages_batch" 0
    return 0
}

# Function to check if package is installed
is_package_installed() {
    local package="$1"
    
    case "$PACKAGE_MANAGER" in
        "apt"|"apt-get")
            dpkg -l "$package" 2>/dev/null | grep -q "^ii"
            ;;
        "dnf"|"yum")
            rpm -q "$package" >/dev/null 2>&1
            ;;
        "pacman")
            pacman -Q "$package" >/dev/null 2>&1
            ;;
        "zypper")
            zypper search -i "$package" | grep -q "^i"
            ;;
        "apk")
            apk info -e "$package" >/dev/null 2>&1
            ;;
        *)
            log_error "Package check not implemented for: $PACKAGE_MANAGER"
            return 1
            ;;
    esac
}

# Function to search for packages
search_package() {
    local search_term="$1"
    
    log_function_enter "search_package"
    log_info "Searching for packages matching: $search_term"
    
    if log_command "$PACKAGE_MANAGER_SEARCH_CMD $search_term" "Search packages"; then
        log_function_exit "search_package" 0
        return 0
    else
        log_function_exit "search_package" 1
        return 1
    fi
}

# Function to remove packages
remove_package() {
    local package="$1"
    local description="${2:-Removing $package}"
    
    log_function_enter "remove_package"
    log_info "Removing package: $package"
    
    print_status "progress" "$description..."
    
    if log_command "sudo $PACKAGE_MANAGER_REMOVE_CMD $package" "Remove package: $package"; then
        print_status "success" "$description completed"
        log_function_exit "remove_package" 0
        return 0
    else
        print_status "error" "$description failed"
        log_function_exit "remove_package" 1
        return 1
    fi
}

# Function to get package manager-specific package names
get_package_name() {
    local generic_name="$1"
    
    case "$PACKAGE_MANAGER" in
        "apt"|"apt-get")
            case "$generic_name" in
                "development-tools") echo "build-essential" ;;
                "python-dev") echo "python3-dev" ;;
                "python-pip") echo "python3-pip" ;;
                *) echo "$generic_name" ;;
            esac
            ;;
        "dnf"|"yum")
            case "$generic_name" in
                "development-tools") echo "gcc gcc-c++ make" ;;
                "python-dev") echo "python3-devel" ;;
                "python-pip") echo "python3-pip" ;;
                *) echo "$generic_name" ;;
            esac
            ;;
        "pacman")
            case "$generic_name" in
                "development-tools") echo "base-devel" ;;
                "python-dev") echo "python" ;;
                "python-pip") echo "python-pip" ;;
                *) echo "$generic_name" ;;
            esac
            ;;
        "zypper")
            case "$generic_name" in
                "development-tools") echo "pattern:devel_basis" ;;
                "python-dev") echo "python3-devel" ;;
                "python-pip") echo "python3-pip" ;;
                *) echo "$generic_name" ;;
            esac
            ;;
        "apk")
            case "$generic_name" in
                "development-tools") echo "build-base" ;;
                "python-dev") echo "python3-dev" ;;
                "python-pip") echo "py3-pip" ;;
                *) echo "$generic_name" ;;
            esac
            ;;
        *)
            echo "$generic_name"
            ;;
    esac
}

# Function to install packages by generic names
install_generic_packages() {
    local generic_packages=("$@")
    local actual_packages=()
    
    log_function_enter "install_generic_packages"
    
    # Convert generic names to package manager-specific names
    for generic_package in "${generic_packages[@]}"; do
        local actual_package=$(get_package_name "$generic_package")
        actual_packages+=($actual_package)
    done
    
    log_info "Generic packages: ${generic_packages[*]}"
    log_info "Actual packages: ${actual_packages[*]}"
    
    install_packages "${actual_packages[@]}"
    
    log_function_exit "install_generic_packages" 0
}

# Function to test package manager functionality
test_package_manager() {
    log_function_enter "test_package_manager"
    
    print_status "progress" "Testing package manager functionality..."
    
    # Test 1: Check if package manager command exists
    if ! command_exists "$PACKAGE_MANAGER_CMD"; then
        print_status "error" "Package manager command not found: $PACKAGE_MANAGER_CMD"
        log_function_exit "test_package_manager" 1
        return 1
    fi
    
    # Test 2: Test update command (dry run where possible)
    case "$PACKAGE_MANAGER" in
        "apt"|"apt-get")
            if ! sudo apt list --upgradable >/dev/null 2>&1; then
                print_status "error" "APT functionality test failed"
                log_function_exit "test_package_manager" 1
                return 1
            fi
            ;;
        "dnf"|"yum")
            if ! sudo "$PACKAGE_MANAGER_CMD" check-update >/dev/null 2>&1; then
                # check-update returns 100 when updates are available, so we check for command existence
                if ! command_exists "$PACKAGE_MANAGER_CMD"; then
                    print_status "error" "$PACKAGE_MANAGER functionality test failed"
                    log_function_exit "test_package_manager" 1
                    return 1
                fi
            fi
            ;;
        "pacman")
            if ! sudo pacman -Sy >/dev/null 2>&1; then
                print_status "error" "Pacman functionality test failed"
                log_function_exit "test_package_manager" 1
                return 1
            fi
            ;;
        "zypper")
            if ! sudo zypper refresh >/dev/null 2>&1; then
                print_status "error" "Zypper functionality test failed"
                log_function_exit "test_package_manager" 1
                return 1
            fi
            ;;
        "apk")
            if ! sudo apk update >/dev/null 2>&1; then
                print_status "error" "APK functionality test failed"
                log_function_exit "test_package_manager" 1
                return 1
            fi
            ;;
        "brew")
            if ! command_exists brew; then
                log_info "Homebrew not found, attempting installation"
                if ! install_homebrew; then
                    print_status "error" "Failed to install Homebrew"
                    log_function_exit "test_package_manager" 1
                    return 1
                fi
            fi
            
            if ! brew --version >/dev/null 2>&1; then
                print_status "error" "Homebrew functionality test failed"
                log_function_exit "test_package_manager" 1
                return 1
            fi
            ;;
    esac
    
    print_status "success" "Package manager functionality test passed"
    log_function_exit "test_package_manager" 0
    return 0
}

# Function to install Homebrew on macOS
install_homebrew() {
    log_function_enter "install_homebrew"
    
    print_status "info" "Installing Homebrew package manager for macOS"
    
    # Check if we're on macOS
    if [[ "$(uname -s)" != "Darwin" ]]; then
        log_error "Homebrew installation is only supported on macOS"
        return 1
    fi
    
    # Check if Homebrew is already installed
    if command_exists brew; then
        log_info "Homebrew is already installed"
        print_status "success" "Homebrew is already available"
        return 0
    fi
    
    # Install Homebrew
    log_info "Downloading and installing Homebrew"
    
    # Use the official Homebrew installation script
    if command_exists curl; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
            log_error "Failed to install Homebrew using curl"
            return 1
        }
    elif command_exists wget; then
        /bin/bash -c "$(wget -qO- https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
            log_error "Failed to install Homebrew using wget"
            return 1
        }
    else
        log_error "Neither curl nor wget available for Homebrew installation"
        return 1
    fi
    
    # Add Homebrew to PATH for current session
    # Homebrew on Apple Silicon (M1/M2) installs to /opt/homebrew
    # Homebrew on Intel Macs installs to /usr/local
    local brew_path=""
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        brew_path="/opt/homebrew/bin"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        brew_path="/usr/local/bin"
    fi
    
    if [[ -n "$brew_path" ]]; then
        export PATH="$brew_path:$PATH"
        log_info "Added Homebrew to PATH: $brew_path"
    fi
    
    # Verify installation
    if command_exists brew; then
        local brew_version
        brew_version=$(brew --version | head -1)
        log_info "Homebrew installed successfully: $brew_version"
        print_status "success" "Homebrew installed: $brew_version"
        
        # Update Homebrew
        brew update || log_warn "Failed to update Homebrew"
        
        log_function_exit "install_homebrew" 0
        return 0
    else
        log_error "Homebrew installation verification failed"
        log_function_exit "install_homebrew" 1
        return 1
    fi
}

# Function to print package manager information
print_package_manager_info() {
    echo "Package Manager Information:"
    echo "  Manager: $PACKAGE_MANAGER"
    echo "  Command: $PACKAGE_MANAGER_CMD"
    echo "  Install: $PACKAGE_MANAGER_INSTALL_CMD"
    echo "  Update: $PACKAGE_MANAGER_UPDATE_CMD"
    echo "  Search: $PACKAGE_MANAGER_SEARCH_CMD"
    echo "  Remove: $PACKAGE_MANAGER_REMOVE_CMD"
}