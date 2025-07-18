#!/bin/bash
#
# Service Configuration Library for Linux Setup
# Implements SSH, firewall, NTP, and security hardening configuration
# User Stories 1.3: Service Configuration and 1.4: User and Permission Setup
#

# Global variables for service configuration
CONFIG_BACKUP_DIR="$LOG_DIR/config_backups"
CONFIG_CHANGES=()
CONFIG_ERRORS=()
CONFIG_WARNINGS=()

# Configuration defaults
SSH_PORT="${SSH_PORT:-22}"
SSH_PERMIT_ROOT="${SSH_PERMIT_ROOT:-no}"
SSH_PASSWORD_AUTH="${SSH_PASSWORD_AUTH:-no}"
SSH_PUBKEY_AUTH="${SSH_PUBKEY_AUTH:-yes}"
SSH_X11_FORWARDING="${SSH_X11_FORWARDING:-no}"

# Firewall defaults
UFW_DEFAULT_INCOMING="${UFW_DEFAULT_INCOMING:-deny}"
UFW_DEFAULT_OUTGOING="${UFW_DEFAULT_OUTGOING:-allow}"
UFW_SSH_RULE="${UFW_SSH_RULE:-limit}"

# Function to backup configuration file
backup_config_file() {
    local config_file="$1"
    local backup_name="$2"
    
    log_function_enter "backup_config_file"
    
    if [[ ! -f "$config_file" ]]; then
        log_warn "Configuration file does not exist: $config_file"
        log_function_exit "backup_config_file" 1
        return 1
    fi
    
    # Create backup directory
    mkdir -p "$CONFIG_BACKUP_DIR"
    
    # Create timestamped backup
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$CONFIG_BACKUP_DIR/${backup_name}_${timestamp}.backup"
    
    if cp "$config_file" "$backup_file"; then
        log_info "Configuration backed up: $config_file -> $backup_file"
        CONFIG_CHANGES+=("Backed up $config_file to $backup_file")
        echo "$backup_file"
        log_function_exit "backup_config_file" 0
        return 0
    else
        log_error "Failed to backup configuration: $config_file"
        CONFIG_ERRORS+=("Failed to backup $config_file")
        log_function_exit "backup_config_file" 1
        return 1
    fi
}

# Function to configure SSH service
configure_ssh_service() {
    log_function_enter "configure_ssh_service"
    log_info "Starting SSH service configuration"
    
    print_status "progress" "Configuring SSH service..."
    
    local ssh_config="/etc/ssh/sshd_config"
    local ssh_backup=""
    
    # Check if SSH is installed
    if ! command_exists ssh || ! command_exists sshd; then
        print_status "warning" "SSH server not installed, installing..."
        if ! install_package "openssh-server" "Installing SSH server"; then
            print_status "error" "Failed to install SSH server"
            CONFIG_ERRORS+=("Failed to install SSH server")
            log_function_exit "configure_ssh_service" 1
            return 1
        fi
    fi
    
    # Backup current SSH configuration
    if [[ -f "$ssh_config" ]]; then
        ssh_backup=$(backup_config_file "$ssh_config" "sshd_config")
        if [[ $? -ne 0 ]]; then
            print_status "error" "Failed to backup SSH configuration"
            log_function_exit "configure_ssh_service" 1
            return 1
        fi
    fi
    
    # Create new SSH configuration
    print_status "progress" "Updating SSH configuration..."
    
    # Use a temporary file for safe configuration
    local temp_config=$(mktemp)
    
    cat > "$temp_config" << EOF
# SSH Configuration - Generated by Linux Setup System
# $(date)
# Backup: $ssh_backup

# Network
Port $SSH_PORT
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

# Authentication
PermitRootLogin $SSH_PERMIT_ROOT
PubkeyAuthentication $SSH_PUBKEY_AUTH
PasswordAuthentication $SSH_PASSWORD_AUTH
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Kerberos options
KerberosAuthentication no
KerberosOrLocalPasswd no
KerberosTicketCleanup yes
KerberosGetAFSToken no

# GSSAPI options
GSSAPIAuthentication no
GSSAPICleanupCredentials yes

# Security
X11Forwarding $SSH_X11_FORWARDING
X11DisplayOffset 10
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 10
MaxStartups 10:30:100

# Logging
SyslogFacility AUTH
LogLevel INFO

# SFTP subsystem
Subsystem sftp /usr/lib/openssh/sftp-server

# Override default of no subsystems
AcceptEnv LANG LC_*
EOF
    
    # Validate SSH configuration
    if sudo sshd -t -f "$temp_config" 2>/dev/null; then
        # Copy to actual location
        if sudo cp "$temp_config" "$ssh_config"; then
            sudo chmod 644 "$ssh_config"
            sudo chown root:root "$ssh_config"
            print_status "success" "SSH configuration updated"
            CONFIG_CHANGES+=("Updated SSH configuration: $ssh_config")
            log_info "SSH configuration updated successfully"
        else
            print_status "error" "Failed to update SSH configuration"
            CONFIG_ERRORS+=("Failed to write SSH configuration")
            rm -f "$temp_config"
            log_function_exit "configure_ssh_service" 1
            return 1
        fi
    else
        print_status "error" "Invalid SSH configuration generated"
        CONFIG_ERRORS+=("Generated invalid SSH configuration")
        rm -f "$temp_config"
        log_function_exit "configure_ssh_service" 1
        return 1
    fi
    
    rm -f "$temp_config"
    
    # Enable and start SSH service
    print_status "progress" "Enabling SSH service..."
    if sudo systemctl enable ssh 2>/dev/null || sudo systemctl enable sshd 2>/dev/null; then
        log_info "SSH service enabled"
        CONFIG_CHANGES+=("SSH service enabled for boot")
        
        # Restart SSH service
        print_status "progress" "Restarting SSH service..."
        if sudo systemctl restart ssh 2>/dev/null || sudo systemctl restart sshd 2>/dev/null; then
            print_status "success" "SSH service restarted successfully"
            CONFIG_CHANGES+=("SSH service restarted")
            log_info "SSH service restarted successfully"
        else
            print_status "warning" "SSH service restart may have failed"
            CONFIG_WARNINGS+=("SSH service restart uncertain")
            log_warn "SSH service restart uncertain"
        fi
    else
        print_status "warning" "Failed to enable SSH service"
        CONFIG_WARNINGS+=("Failed to enable SSH service")
        log_warn "Failed to enable SSH service"
    fi
    
    # Verify SSH is running
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        print_status "success" "SSH service is active"
        log_info "SSH service verification: active"
    else
        print_status "warning" "SSH service may not be running"
        CONFIG_WARNINGS+=("SSH service status uncertain")
        log_warn "SSH service status uncertain"
    fi
    
    log_function_exit "configure_ssh_service" 0
    return 0
}

# Function to configure UFW firewall
configure_ufw_firewall() {
    log_function_enter "configure_ufw_firewall"
    log_info "Starting UFW firewall configuration"
    
    print_status "progress" "Configuring UFW firewall..."
    
    # Check if UFW is installed
    if ! command_exists ufw; then
        print_status "warning" "UFW not installed, installing..."
        if ! install_package "ufw" "Installing UFW firewall"; then
            print_status "error" "Failed to install UFW"
            CONFIG_ERRORS+=("Failed to install UFW")
            log_function_exit "configure_ufw_firewall" 1
            return 1
        fi
    fi
    
    # Reset UFW to default state
    print_status "progress" "Resetting UFW to defaults..."
    if sudo ufw --force reset >/dev/null 2>&1; then
        log_info "UFW reset to defaults"
        CONFIG_CHANGES+=("UFW reset to default configuration")
    else
        log_warn "UFW reset may have failed"
        CONFIG_WARNINGS+=("UFW reset uncertain")
    fi
    
    # Set default policies
    print_status "progress" "Setting UFW default policies..."
    sudo ufw default "$UFW_DEFAULT_INCOMING" incoming >/dev/null 2>&1
    sudo ufw default "$UFW_DEFAULT_OUTGOING" outgoing >/dev/null 2>&1
    CONFIG_CHANGES+=("UFW defaults: incoming $UFW_DEFAULT_INCOMING, outgoing $UFW_DEFAULT_OUTGOING")
    log_info "UFW default policies set: incoming=$UFW_DEFAULT_INCOMING, outgoing=$UFW_DEFAULT_OUTGOING"
    
    # Allow SSH with rate limiting
    print_status "progress" "Configuring SSH access rule..."
    if [[ "$UFW_SSH_RULE" == "limit" ]]; then
        sudo ufw limit "$SSH_PORT/tcp" >/dev/null 2>&1
        CONFIG_CHANGES+=("UFW rule: limit SSH on port $SSH_PORT/tcp")
        log_info "UFW SSH rule: rate limiting on port $SSH_PORT"
    else
        sudo ufw allow "$SSH_PORT/tcp" >/dev/null 2>&1
        CONFIG_CHANGES+=("UFW rule: allow SSH on port $SSH_PORT/tcp")
        log_info "UFW SSH rule: allow on port $SSH_PORT"
    fi
    
    # Allow common outgoing ports
    print_status "progress" "Configuring outgoing rules..."
    local outgoing_ports=("53" "80" "443" "123")
    for port in "${outgoing_ports[@]}"; do
        sudo ufw allow out "$port" >/dev/null 2>&1
    done
    CONFIG_CHANGES+=("UFW outgoing rules: DNS(53), HTTP(80), HTTPS(443), NTP(123)")
    log_info "UFW outgoing rules configured for essential services"
    
    # Enable UFW
    print_status "progress" "Enabling UFW firewall..."
    if sudo ufw --force enable >/dev/null 2>&1; then
        print_status "success" "UFW firewall enabled"
        CONFIG_CHANGES+=("UFW firewall enabled and active")
        log_info "UFW firewall enabled successfully"
    else
        print_status "error" "Failed to enable UFW firewall"
        CONFIG_ERRORS+=("Failed to enable UFW firewall")
        log_function_exit "configure_ufw_firewall" 1
        return 1
    fi
    
    # Verify UFW status
    if sudo ufw status | grep -q "Status: active"; then
        print_status "success" "UFW is active"
        log_info "UFW status verification: active"
    else
        print_status "warning" "UFW status uncertain"
        CONFIG_WARNINGS+=("UFW status verification failed")
        log_warn "UFW status verification failed"
    fi
    
    log_function_exit "configure_ufw_firewall" 0
    return 0
}

# Function to configure NTP/timesyncd
configure_time_sync() {
    log_function_enter "configure_time_sync"
    log_info "Starting time synchronization configuration"
    
    print_status "progress" "Configuring time synchronization..."
    
    # Check if systemd-timesyncd is available (modern systems)
    log_debug "Checking for systemd-timesyncd availability"
    if systemctl list-unit-files 2>/dev/null | grep -q "systemd-timesyncd.service"; then
        log_info "systemd-timesyncd detected, configuring..."
        print_status "progress" "Configuring systemd-timesyncd..."
        
        # Configure timesyncd
        local timesyncd_config="/etc/systemd/timesyncd.conf"
        if [[ -f "$timesyncd_config" ]]; then
            backup_config_file "$timesyncd_config" "timesyncd_conf"
        fi
        
        # Create timesyncd configuration
        sudo tee "$timesyncd_config" > /dev/null << EOF
# Time synchronization configuration - Generated by Linux Setup System
# $(date)

[Time]
NTP=0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org
FallbackNTP=time.cloudflare.com time.google.com
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
EOF
        
        # Enable and start timesyncd
        if sudo systemctl enable systemd-timesyncd >/dev/null 2>&1; then
            CONFIG_CHANGES+=("systemd-timesyncd enabled")
            log_info "systemd-timesyncd enabled"
            
            if sudo systemctl restart systemd-timesyncd >/dev/null 2>&1; then
                print_status "success" "Time synchronization configured (systemd-timesyncd)"
                CONFIG_CHANGES+=("systemd-timesyncd restarted and configured")
                log_info "systemd-timesyncd configured successfully"
            else
                print_status "warning" "systemd-timesyncd restart failed"
                CONFIG_WARNINGS+=("systemd-timesyncd restart failed")
                log_warn "systemd-timesyncd restart failed"
            fi
        else
            print_status "warning" "Failed to enable systemd-timesyncd"
            CONFIG_WARNINGS+=("Failed to enable systemd-timesyncd")
            log_warn "Failed to enable systemd-timesyncd"
        fi
        
    # Fallback to NTP daemon
    elif command_exists ntpd; then
        log_info "Existing ntpd detected, configuring..."
        print_status "progress" "Using existing NTP daemon..."
    elif install_package "ntp" "Installing NTP daemon"; then
        log_info "Installing and configuring NTP daemon..."
        print_status "progress" "Configuring NTP daemon..."
        
        local ntp_config="/etc/ntp.conf"
        if [[ -f "$ntp_config" ]]; then
            backup_config_file "$ntp_config" "ntp_conf"
        fi
        
        # Create NTP configuration
        sudo tee "$ntp_config" > /dev/null << EOF
# NTP configuration - Generated by Linux Setup System
# $(date)

driftfile /var/lib/ntp/ntp.drift

# Leap seconds definition provided by tzdata
leapfile /usr/share/zoneinfo/leap-seconds.list

# NTP servers
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst
server 3.pool.ntp.org iburst

# Fallback servers
server time.cloudflare.com iburst
server time.google.com iburst

# Restrict access
restrict -4 default kod notrap nomodify nopeer noquery limited
restrict -6 default kod notrap nomodify nopeer noquery limited
restrict 127.0.0.1
restrict ::1
restrict source notrap nomodify noquery
EOF
        
        # Enable and start NTP
        if sudo systemctl enable ntp >/dev/null 2>&1; then
            CONFIG_CHANGES+=("NTP daemon enabled")
            log_info "NTP daemon enabled"
            
            if sudo systemctl restart ntp >/dev/null 2>&1; then
                print_status "success" "Time synchronization configured (NTP daemon)"
                CONFIG_CHANGES+=("NTP daemon restarted and configured")
                log_info "NTP daemon configured successfully"
            else
                print_status "warning" "NTP daemon restart failed"
                CONFIG_WARNINGS+=("NTP daemon restart failed")
                log_warn "NTP daemon restart failed"
            fi
        else
            print_status "warning" "Failed to enable NTP daemon"
            CONFIG_WARNINGS+=("Failed to enable NTP daemon")
            log_warn "Failed to enable NTP daemon"
        fi
    else
        print_status "error" "No time synchronization method available"
        CONFIG_ERRORS+=("No time synchronization method available")
        log_function_exit "configure_time_sync" 1
        return 1
    fi
    
    # Verify time sync status
    if systemctl is-active --quiet systemd-timesyncd 2>/dev/null || 
       systemctl is-active --quiet ntp 2>/dev/null; then
        print_status "success" "Time synchronization is active"
        log_info "Time synchronization verification: active"
    else
        print_status "warning" "Time synchronization status uncertain"
        CONFIG_WARNINGS+=("Time synchronization status uncertain")
        log_warn "Time synchronization status uncertain"
    fi
    
    log_function_exit "configure_time_sync" 0
    return 0
}

# Function to install and configure fail2ban
configure_fail2ban() {
    log_function_enter "configure_fail2ban"
    log_info "Starting fail2ban configuration"
    
    print_status "progress" "Installing and configuring fail2ban..."
    
    # Install fail2ban
    if ! command_exists fail2ban-server; then
        if ! install_package "fail2ban" "Installing fail2ban"; then
            print_status "error" "Failed to install fail2ban"
            CONFIG_ERRORS+=("Failed to install fail2ban")
            log_function_exit "configure_fail2ban" 1
            return 1
        fi
    fi
    
    # Create fail2ban local configuration
    local jail_local="/etc/fail2ban/jail.local"
    backup_config_file "$jail_local" "jail_local" 2>/dev/null || true
    
    print_status "progress" "Configuring fail2ban rules..."
    
    sudo tee "$jail_local" > /dev/null << EOF
# Fail2ban configuration - Generated by Linux Setup System
# $(date)

[DEFAULT]
# Ban hosts for 1 hour
bantime = 3600

# A host is banned if it has generated "maxretry" during the last "findtime" seconds
findtime = 600
maxretry = 3

# Destination email for action that send you an email
destemail = root@localhost
sender = root@localhost

# MTA (mail transfer agent) used to send mail
mta = sendmail

# Default protocol
protocol = tcp

# Specify chain where jumps would need to be added in iptables-* actions
chain = INPUT

# SSH jail
[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF
    
    CONFIG_CHANGES+=("fail2ban configuration created: $jail_local")
    log_info "fail2ban local configuration created"
    
    # Enable and start fail2ban
    if sudo systemctl enable fail2ban >/dev/null 2>&1; then
        CONFIG_CHANGES+=("fail2ban service enabled")
        log_info "fail2ban service enabled"
        
        if sudo systemctl restart fail2ban >/dev/null 2>&1; then
            print_status "success" "fail2ban configured and started"
            CONFIG_CHANGES+=("fail2ban service restarted")
            log_info "fail2ban configured successfully"
        else
            print_status "warning" "fail2ban restart failed"
            CONFIG_WARNINGS+=("fail2ban restart failed")
            log_warn "fail2ban restart failed"
        fi
    else
        print_status "warning" "Failed to enable fail2ban"
        CONFIG_WARNINGS+=("Failed to enable fail2ban")
        log_warn "Failed to enable fail2ban"
    fi
    
    # Verify fail2ban status
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        print_status "success" "fail2ban is active"
        log_info "fail2ban verification: active"
    else
        print_status "warning" "fail2ban status uncertain"
        CONFIG_WARNINGS+=("fail2ban status uncertain")
        log_warn "fail2ban status uncertain"
    fi
    
    log_function_exit "configure_fail2ban" 0
    return 0
}

# Function to configure all services
configure_all_services() {
    log_function_enter "configure_all_services"
    log_info "Starting comprehensive service configuration"
    
    # Reset counters
    CONFIG_CHANGES=()
    CONFIG_ERRORS=()
    CONFIG_WARNINGS=()
    
    print_status "progress" "Starting service configuration..."
    echo "🔧 Configuring Essential Services"
    echo "================================="
    
    local services_configured=0
    local services_failed=0
    
    # Configure SSH
    echo ""
    echo "🔐 SSH Service Configuration"
    if configure_ssh_service; then
        ((services_configured++))
    else
        ((services_failed++))
    fi
    
    # Configure Firewall
    echo ""
    echo "🔥 Firewall Configuration"
    if configure_ufw_firewall; then
        ((services_configured++))
    else
        ((services_failed++))
    fi
    
    # Configure Time Sync
    echo ""
    echo "⏰ Time Synchronization Configuration"
    if configure_time_sync; then
        ((services_configured++))
    else
        ((services_failed++))
    fi
    
    # Configure fail2ban
    echo ""
    echo "🛡️ fail2ban Configuration"
    if configure_fail2ban; then
        ((services_configured++))
    else
        ((services_failed++))
    fi
    
    # Summary
    echo ""
    echo "📊 Service Configuration Summary"
    echo "==============================="
    echo "✅ Services configured: $services_configured"
    echo "❌ Services failed: $services_failed"
    echo "📝 Configuration changes: ${#CONFIG_CHANGES[@]}"
    echo "⚠️  Warnings: ${#CONFIG_WARNINGS[@]}"
    echo "❌ Errors: ${#CONFIG_ERRORS[@]}"
    
    if [[ ${#CONFIG_CHANGES[@]} -gt 0 ]]; then
        echo ""
        echo "📋 Configuration Changes:"
        for change in "${CONFIG_CHANGES[@]}"; do
            echo "   ✅ $change"
        done
    fi
    
    if [[ ${#CONFIG_WARNINGS[@]} -gt 0 ]]; then
        echo ""
        echo "⚠️  Warnings:"
        for warning in "${CONFIG_WARNINGS[@]}"; do
            echo "   ⚠️  $warning"
        done
    fi
    
    if [[ ${#CONFIG_ERRORS[@]} -gt 0 ]]; then
        echo ""
        echo "❌ Errors:"
        for error in "${CONFIG_ERRORS[@]}"; do
            echo "   ❌ $error"
        done
    fi
    
    echo ""
    if [[ $services_failed -eq 0 ]]; then
        print_status "success" "All services configured successfully!"
        log_info "Service configuration completed successfully: $services_configured/$((services_configured + services_failed)) services"
    elif [[ $services_configured -gt $services_failed ]]; then
        print_status "warning" "Service configuration completed with some issues"
        log_warn "Service configuration completed with issues: $services_configured/$((services_configured + services_failed)) services successful"
    else
        print_status "error" "Service configuration failed"
        log_error "Service configuration failed: $services_configured/$((services_configured + services_failed)) services successful"
    fi
    
    log_info "Service configuration summary: $services_configured configured, $services_failed failed, ${#CONFIG_CHANGES[@]} changes, ${#CONFIG_WARNINGS[@]} warnings, ${#CONFIG_ERRORS[@]} errors"
    log_function_exit "configure_all_services" $services_failed
    return $services_failed
}

# Function to create administrative user
create_admin_user() {
    local username="$1"
    local ssh_key="$2"
    local full_name="${3:-$username}"
    
    log_function_enter "create_admin_user"
    log_info "Creating administrative user: $username"
    
    print_status "progress" "Creating user: $username"
    
    # Check if user already exists
    if id "$username" >/dev/null 2>&1; then
        print_status "info" "User $username already exists"
        log_info "User $username already exists, updating configuration"
    else
        # Create user with home directory
        if sudo useradd -m -s /bin/bash -c "$full_name" "$username"; then
            print_status "success" "User $username created"
            CONFIG_CHANGES+=("Created user: $username")
            log_info "User $username created successfully"
        else
            print_status "error" "Failed to create user: $username"
            CONFIG_ERRORS+=("Failed to create user: $username")
            log_function_exit "create_admin_user" 1
            return 1
        fi
    fi
    
    # Add user to sudo group
    print_status "progress" "Adding $username to sudo group"
    if sudo usermod -aG sudo "$username"; then
        print_status "success" "User $username added to sudo group"
        CONFIG_CHANGES+=("Added $username to sudo group")
        log_info "User $username added to sudo group"
    else
        print_status "warning" "Failed to add $username to sudo group"
        CONFIG_WARNINGS+=("Failed to add $username to sudo group")
        log_warn "Failed to add $username to sudo group"
    fi
    
    # Set up SSH key authentication if key provided
    if [[ -n "$ssh_key" ]]; then
        print_status "progress" "Setting up SSH key for $username"
        
        local ssh_dir="/home/$username/.ssh"
        local authorized_keys="$ssh_dir/authorized_keys"
        
        # Create .ssh directory
        sudo mkdir -p "$ssh_dir"
        sudo chmod 700 "$ssh_dir"
        sudo chown "$username:$username" "$ssh_dir"
        
        # Add SSH key
        echo "$ssh_key" | sudo tee "$authorized_keys" > /dev/null
        sudo chmod 600 "$authorized_keys"
        sudo chown "$username:$username" "$authorized_keys"
        
        print_status "success" "SSH key configured for $username"
        CONFIG_CHANGES+=("SSH key configured for user: $username")
        log_info "SSH key configured for user: $username"
    fi
    
    # Set secure permissions on home directory
    sudo chmod 755 "/home/$username"
    sudo chown "$username:$username" "/home/$username"
    
    log_function_exit "create_admin_user" 0
    return 0
}

# Function to configure sudo access
configure_sudo_access() {
    log_function_enter "configure_sudo_access"
    log_info "Configuring sudo access policies"
    
    print_status "progress" "Configuring sudo policies..."
    
    # Install sudo if not present
    if ! command_exists sudo; then
        if ! install_package "sudo" "Installing sudo"; then
            print_status "error" "Failed to install sudo"
            CONFIG_ERRORS+=("Failed to install sudo")
            log_function_exit "configure_sudo_access" 1
            return 1
        fi
    fi
    
    # Create secure sudoers configuration
    local sudoers_custom="/etc/sudoers.d/99-admin-users"
    
    print_status "progress" "Creating secure sudoers configuration"
    
    sudo tee "$sudoers_custom" > /dev/null << 'EOF'
# Custom sudoers configuration - Generated by Linux Setup System
# This file provides secure sudo access for administrative users

# Require password for sudo commands
Defaults passwd_tries=3
Defaults passwd_timeout=5
Defaults timestamp_timeout=15

# Log sudo commands
Defaults logfile=/var/log/sudo.log
Defaults log_input, log_output

# Secure PATH
Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Allow sudo group members to execute any command
%sudo ALL=(ALL:ALL) ALL

# Prevent privilege escalation attacks
Defaults use_pty
Defaults requiretty
EOF
    
    # Set proper permissions
    sudo chmod 440 "$sudoers_custom"
    sudo chown root:root "$sudoers_custom"
    
    # Verify sudoers syntax
    if sudo visudo -c; then
        print_status "success" "Sudoers configuration updated"
        CONFIG_CHANGES+=("Updated sudoers configuration: $sudoers_custom")
        log_info "Sudoers configuration updated successfully"
    else
        print_status "error" "Invalid sudoers configuration"
        sudo rm -f "$sudoers_custom"
        CONFIG_ERRORS+=("Invalid sudoers configuration generated")
        log_function_exit "configure_sudo_access" 1
        return 1
    fi
    
    log_function_exit "configure_sudo_access" 0
    return 0
}

# Function to secure file permissions
secure_system_permissions() {
    log_function_enter "secure_system_permissions"
    log_info "Securing system file permissions"
    
    print_status "progress" "Securing system file permissions..."
    
    local secured_files=0
    local permission_errors=0
    
    # Define critical files and their permissions
    local critical_files=(
        "/etc/passwd:644"
        "/etc/shadow:640"
        "/etc/group:644"
        "/etc/gshadow:640"
        "/etc/sudoers:440"
        "/etc/ssh/sshd_config:644"
        "/etc/fstab:644"
        "/etc/hosts:644"
        "/boot/grub/grub.cfg:400"
    )
    
    for file_perm in "${critical_files[@]}"; do
        local file=$(echo "$file_perm" | cut -d':' -f1)
        local perm=$(echo "$file_perm" | cut -d':' -f2)
        
        if [[ -f "$file" ]]; then
            local current_perm=$(stat -c "%a" "$file" 2>/dev/null)
            if [[ "$current_perm" != "$perm" ]]; then
                if sudo chmod "$perm" "$file" 2>/dev/null; then
                    print_status "info" "Fixed permissions: $file ($current_perm -> $perm)"
                    CONFIG_CHANGES+=("Fixed permissions: $file ($current_perm -> $perm)")
                    ((secured_files++))
                else
                    print_status "warning" "Failed to fix permissions: $file"
                    CONFIG_WARNINGS+=("Failed to fix permissions: $file")
                    ((permission_errors++))
                fi
            fi
        fi
    done
    
    # Secure SSH directory permissions
    if [[ -d "/etc/ssh" ]]; then
        sudo chmod 755 "/etc/ssh"
        sudo find /etc/ssh -name "ssh_host_*_key" -exec chmod 600 {} \; 2>/dev/null
        sudo find /etc/ssh -name "ssh_host_*_key.pub" -exec chmod 644 {} \; 2>/dev/null
        CONFIG_CHANGES+=("Secured SSH key permissions")
        ((secured_files++))
    fi
    
    # Secure log directory permissions
    if [[ -d "/var/log" ]]; then
        sudo chmod 755 "/var/log"
        sudo find /var/log -type f -exec chmod 640 {} \; 2>/dev/null || true
        CONFIG_CHANGES+=("Secured log file permissions")
        ((secured_files++))
    fi
    
    print_status "success" "System permissions secured ($secured_files files processed)"
    log_info "System permissions secured: $secured_files files processed, $permission_errors errors"
    
    log_function_exit "secure_system_permissions" 0
    return 0
}

# Function to configure user management
configure_user_management() {
    local admin_username="${1:-}"
    local admin_ssh_key="${2:-}"
    local admin_fullname="${3:-}"
    
    log_function_enter "configure_user_management"
    log_info "Starting user and permission management configuration"
    
    print_status "progress" "Configuring user management..."
    echo "👥 User and Permission Management"
    echo "================================"
    
    # Configure sudo access
    echo ""
    echo "🔐 Configuring sudo access"
    configure_sudo_access
    
    # Create admin user if specified
    if [[ -n "$admin_username" ]]; then
        echo ""
        echo "👤 Creating administrative user"
        create_admin_user "$admin_username" "$admin_ssh_key" "$admin_fullname"
    fi
    
    # Secure system permissions
    echo ""
    echo "🔒 Securing system permissions"
    secure_system_permissions
    
    print_status "success" "User management configuration completed"
    log_function_exit "configure_user_management" 0
    return 0
}

# Function to generate service configuration report
generate_service_config_report() {
    local report_file="$LOG_DIR/service-config-report-$(date +%Y%m%d-%H%M%S).txt"
    
    log_function_enter "generate_service_config_report"
    log_info "Generating service configuration report: $report_file"
    
    {
        echo "=========================================================================="
        echo "Linux Service Configuration Report"
        echo "=========================================================================="
        echo "Generated: $(date)"
        echo "System: $DISTRO_NAME $DISTRO_VERSION ($DISTRO_ARCHITECTURE)"
        echo "Hostname: $(hostname)"
        echo "=========================================================================="
        echo ""
        
        echo "CONFIGURATION SUMMARY:"
        echo "  Services Configured: $services_configured"
        echo "  Configuration Changes: ${#CONFIG_CHANGES[@]}"
        echo "  Warnings: ${#CONFIG_WARNINGS[@]}"
        echo "  Errors: ${#CONFIG_ERRORS[@]}"
        echo ""
        
        if [[ ${#CONFIG_CHANGES[@]} -gt 0 ]]; then
            echo "CONFIGURATION CHANGES:"
            for change in "${CONFIG_CHANGES[@]}"; do
                echo "  + $change"
            done
            echo ""
        fi
        
        if [[ ${#CONFIG_WARNINGS[@]} -gt 0 ]]; then
            echo "WARNINGS:"
            for warning in "${CONFIG_WARNINGS[@]}"; do
                echo "  ! $warning"
            done
            echo ""
        fi
        
        if [[ ${#CONFIG_ERRORS[@]} -gt 0 ]]; then
            echo "ERRORS:"
            for error in "${CONFIG_ERRORS[@]}"; do
                echo "  - $error"
            done
            echo ""
        fi
        
        echo "BACKUP LOCATION:"
        echo "  Configuration backups: $CONFIG_BACKUP_DIR"
        echo ""
        
        echo "=========================================================================="
        echo "Report generated by Generic Linux Setup & Monitoring System"
        echo "=========================================================================="
        
    } > "$report_file"
    
    print_status "success" "Service configuration report generated: $report_file"
    log_info "Service configuration report generated: $report_file"
    log_function_exit "generate_service_config_report" 0
    return 0
}