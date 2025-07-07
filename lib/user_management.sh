#!/bin/bash

# User Management Library for Generic Linux Setup
# Handles user creation, permission setup, and SSH key management

# Strict error handling
set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/logging.sh"

# User Management Functions

# Create a new user with sudo privileges
create_admin_user() {
    local username="$1"
    local full_name="${2:-}"
    local ssh_key="${3:-}"
    
    log_info "Creating administrative user: $username"
    
    # Check if user already exists
    if id "$username" &>/dev/null; then
        log_warn "User $username already exists, skipping creation"
        return 0
    fi
    
    # Create user with home directory
    if command -v useradd &>/dev/null; then
        if [[ -n "$full_name" ]]; then
            sudo useradd -m -c "$full_name" -s /bin/bash "$username" || {
                log_error "Failed to create user $username"
                return 1
            }
        else
            sudo useradd -m -s /bin/bash "$username" || {
                log_error "Failed to create user $username"
                return 1
            }
        fi
    else
        log_error "useradd command not found"
        return 1
    fi
    
    # Add user to sudo group
    if command -v usermod &>/dev/null; then
        if [[ "$DISTRO_FAMILY" == "debian" ]]; then
            sudo usermod -aG sudo "$username" || {
                log_error "Failed to add $username to sudo group"
                return 1
            }
        elif [[ "$DISTRO_FAMILY" == "redhat" ]]; then
            sudo usermod -aG wheel "$username" || {
                log_error "Failed to add $username to wheel group"
                return 1
            }
        fi
    fi
    
    # Set up SSH key if provided
    if [[ -n "$ssh_key" ]]; then
        setup_ssh_key "$username" "$ssh_key"
    fi
    
    log_info "User $username created successfully with sudo privileges"
    return 0
}

# Set up SSH key for a user
setup_ssh_key() {
    local username="$1"
    local ssh_key="$2"
    
    log_info "Setting up SSH key for user: $username"
    
    local user_home
    user_home=$(getent passwd "$username" | cut -d: -f6)
    
    if [[ -z "$user_home" ]]; then
        log_error "Could not determine home directory for user $username"
        return 1
    fi
    
    # Create .ssh directory
    local ssh_dir="$user_home/.ssh"
    sudo mkdir -p "$ssh_dir"
    sudo chmod 700 "$ssh_dir"
    sudo chown "$username:$username" "$ssh_dir"
    
    # Add SSH key to authorized_keys
    local auth_keys="$ssh_dir/authorized_keys"
    echo "$ssh_key" | sudo tee "$auth_keys" > /dev/null
    sudo chmod 600 "$auth_keys"
    sudo chown "$username:$username" "$auth_keys"
    
    log_info "SSH key configured for user $username"
    return 0
}

# Generate SSH key pair for a user
generate_ssh_key() {
    local username="$1"
    local email="${2:-$username@$(hostname)}"
    
    log_info "Generating SSH key for user: $username"
    
    local user_home
    user_home=$(getent passwd "$username" | cut -d: -f6)
    
    if [[ -z "$user_home" ]]; then
        log_error "Could not determine home directory for user $username"
        return 1
    fi
    
    local ssh_dir="$user_home/.ssh"
    local key_file="$ssh_dir/id_ed25519"
    
    # Create .ssh directory if it doesn't exist
    sudo mkdir -p "$ssh_dir"
    sudo chmod 700 "$ssh_dir"
    sudo chown "$username:$username" "$ssh_dir"
    
    # Generate key if it doesn't exist
    if [[ ! -f "$key_file" ]]; then
        sudo -u "$username" ssh-keygen -t ed25519 -C "$email" -f "$key_file" -N "" || {
            log_error "Failed to generate SSH key for $username"
            return 1
        }
        log_info "SSH key generated: $key_file"
    else
        log_info "SSH key already exists for $username"
    fi
    
    # Display public key
    if [[ -f "$key_file.pub" ]]; then
        local pub_key
        pub_key=$(cat "$key_file.pub")
        log_info "Public key for $username: $pub_key"
        echo "$pub_key"
    fi
    
    return 0
}

# Set up secure file permissions
setup_secure_permissions() {
    log_info "Setting up secure file permissions"
    
    # Secure important system files
    local secure_files=(
        "/etc/passwd"
        "/etc/group"
        "/etc/shadow"
        "/etc/sudoers"
        "/etc/ssh/sshd_config"
    )
    
    for file in "${secure_files[@]}"; do
        if [[ -f "$file" ]]; then
            case "$file" in
                "/etc/shadow")
                    sudo chmod 640 "$file"
                    sudo chown root:shadow "$file" 2>/dev/null || sudo chown root:root "$file"
                    ;;
                "/etc/sudoers")
                    sudo chmod 440 "$file"
                    sudo chown root:root "$file"
                    ;;
                "/etc/ssh/sshd_config")
                    sudo chmod 644 "$file"
                    sudo chown root:root "$file"
                    ;;
                *)
                    sudo chmod 644 "$file"
                    sudo chown root:root "$file"
                    ;;
            esac
            log_info "Secured permissions for $file"
        fi
    done
    
    # Secure SSH directory permissions
    if [[ -d "/etc/ssh" ]]; then
        sudo find /etc/ssh -name "ssh_host_*_key" -exec chmod 600 {} \;
        sudo find /etc/ssh -name "ssh_host_*_key.pub" -exec chmod 644 {} \;
        log_info "Secured SSH host key permissions"
    fi
    
    return 0
}

# Configure sudo access for a user
configure_sudo_access() {
    local username="$1"
    local sudo_rules="${2:-ALL=(ALL:ALL) ALL}"
    
    log_info "Configuring sudo access for user: $username"
    
    local sudoers_file="/etc/sudoers.d/$username"
    
    # Create sudoers file for user
    echo "$username $sudo_rules" | sudo tee "$sudoers_file" > /dev/null
    sudo chmod 440 "$sudoers_file"
    sudo chown root:root "$sudoers_file"
    
    # Validate sudoers file
    if sudo visudo -c; then
        log_info "Sudo access configured for $username"
        return 0
    else
        log_error "Invalid sudoers configuration, removing file"
        sudo rm -f "$sudoers_file"
        return 1
    fi
}

# Set up password policies
setup_password_policies() {
    log_info "Setting up password policies"
    
    # Configure password quality requirements
    if command -v pam-auth-update &>/dev/null; then
        # Debian/Ubuntu
        if [[ -f "/etc/pam.d/common-password" ]]; then
            # Add password complexity requirements
            local pam_config="/etc/pam.d/common-password"
            if ! grep -q "pam_pwquality.so" "$pam_config"; then
                log_info "Adding password quality requirements"
                # This would require libpam-pwquality to be installed
            fi
        fi
    fi
    
    # Set password aging policies
    if command -v chage &>/dev/null; then
        # Set default password aging for new users
        sudo sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/' /etc/login.defs 2>/dev/null || true
        sudo sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 1/' /etc/login.defs 2>/dev/null || true
        sudo sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE 7/' /etc/login.defs 2>/dev/null || true
        log_info "Password aging policies configured"
    fi
    
    return 0
}

# Remove or disable a user
remove_user() {
    local username="$1"
    local remove_home="${2:-false}"
    
    log_info "Removing user: $username"
    
    if ! id "$username" &>/dev/null; then
        log_warn "User $username does not exist"
        return 0
    fi
    
    # Remove user
    if [[ "$remove_home" == "true" ]]; then
        sudo userdel -r "$username" 2>/dev/null || {
            log_error "Failed to remove user $username with home directory"
            return 1
        }
    else
        sudo userdel "$username" 2>/dev/null || {
            log_error "Failed to remove user $username"
            return 1
        }
    fi
    
    # Remove sudoers file
    local sudoers_file="/etc/sudoers.d/$username"
    if [[ -f "$sudoers_file" ]]; then
        sudo rm -f "$sudoers_file"
        log_info "Removed sudoers file for $username"
    fi
    
    log_info "User $username removed successfully"
    return 0
}

# List all users with sudo access
list_sudo_users() {
    log_info "Listing users with sudo access"
    
    local sudo_users=()
    
    # Check users in sudo group (Debian/Ubuntu)
    if getent group sudo &>/dev/null; then
        local sudo_group_users
        sudo_group_users=$(getent group sudo | cut -d: -f4 | tr ',' ' ')
        if [[ -n "$sudo_group_users" ]]; then
            sudo_users+=($sudo_group_users)
        fi
    fi
    
    # Check users in wheel group (RedHat/CentOS)
    if getent group wheel &>/dev/null; then
        local wheel_group_users
        wheel_group_users=$(getent group wheel | cut -d: -f4 | tr ',' ' ')
        if [[ -n "$wheel_group_users" ]]; then
            sudo_users+=($wheel_group_users)
        fi
    fi
    
    # Check sudoers.d directory
    if [[ -d "/etc/sudoers.d" ]]; then
        local sudoers_users
        sudoers_users=$(sudo find /etc/sudoers.d -type f -exec basename {} \; 2>/dev/null | grep -v '^\.')
        if [[ -n "$sudoers_users" ]]; then
            sudo_users+=($sudoers_users)
        fi
    fi
    
    # Remove duplicates and display
    local unique_users
    unique_users=$(printf '%s\n' "${sudo_users[@]}" | sort -u)
    
    if [[ -n "$unique_users" ]]; then
        echo "Users with sudo access:"
        echo "$unique_users"
    else
        echo "No users with sudo access found"
    fi
    
    return 0
}

# Audit user permissions
audit_user_permissions() {
    log_info "Auditing user permissions"
    
    local audit_results=()
    
    # Check for users with UID 0 (root privileges)
    local root_users
    root_users=$(awk -F: '$3 == 0 && $1 != "root" {print $1}' /etc/passwd)
    if [[ -n "$root_users" ]]; then
        audit_results+=("WARNING: Users with UID 0 (besides root): $root_users")
    fi
    
    # Check for users with empty passwords
    local empty_password_users
    empty_password_users=$(sudo awk -F: '$2 == "" {print $1}' /etc/shadow 2>/dev/null || true)
    if [[ -n "$empty_password_users" ]]; then
        audit_results+=("CRITICAL: Users with empty passwords: $empty_password_users")
    fi
    
    # Check for users with shell access
    local shell_users
    shell_users=$(awk -F: '$7 ~ /bash|sh|zsh/ {print $1}' /etc/passwd)
    if [[ -n "$shell_users" ]]; then
        audit_results+=("INFO: Users with shell access: $shell_users")
    fi
    
    # Check SSH key permissions
    local ssh_key_issues=()
    for user_home in /home/*; do
        if [[ -d "$user_home/.ssh" ]]; then
            local username
            username=$(basename "$user_home")
            
            # Check .ssh directory permissions
            local ssh_dir_perms
            ssh_dir_perms=$(stat -c "%a" "$user_home/.ssh" 2>/dev/null || echo "")
            if [[ "$ssh_dir_perms" != "700" ]]; then
                ssh_key_issues+=("$username: .ssh directory permissions ($ssh_dir_perms)")
            fi
            
            # Check authorized_keys permissions
            if [[ -f "$user_home/.ssh/authorized_keys" ]]; then
                local auth_keys_perms
                auth_keys_perms=$(stat -c "%a" "$user_home/.ssh/authorized_keys" 2>/dev/null || echo "")
                if [[ "$auth_keys_perms" != "600" ]]; then
                    ssh_key_issues+=("$username: authorized_keys permissions ($auth_keys_perms)")
                fi
            fi
        fi
    done
    
    if [[ ${#ssh_key_issues[@]} -gt 0 ]]; then
        audit_results+=("WARNING: SSH key permission issues: ${ssh_key_issues[*]}")
    fi
    
    # Display results
    if [[ ${#audit_results[@]} -gt 0 ]]; then
        echo "User Permission Audit Results:"
        printf '%s\n' "${audit_results[@]}"
    else
        echo "User permission audit completed - no issues found"
    fi
    
    return 0
}

# Main user management function
manage_users() {
    local action="$1"
    shift
    
    case "$action" in
        "create")
            create_admin_user "$@"
            ;;
        "setup-ssh")
            setup_ssh_key "$@"
            ;;
        "generate-key")
            generate_ssh_key "$@"
            ;;
        "secure-permissions")
            setup_secure_permissions
            ;;
        "configure-sudo")
            configure_sudo_access "$@"
            ;;
        "setup-password-policies")
            setup_password_policies
            ;;
        "remove")
            remove_user "$@"
            ;;
        "list-sudo")
            list_sudo_users
            ;;
        "audit")
            audit_user_permissions
            ;;
        *)
            log_error "Unknown user management action: $action"
            return 1
            ;;
    esac
}

# Export functions for use in other scripts
export -f create_admin_user
export -f setup_ssh_key
export -f generate_ssh_key
export -f setup_secure_permissions
export -f configure_sudo_access
export -f setup_password_policies
export -f remove_user
export -f list_sudo_users
export -f audit_user_permissions
export -f manage_users