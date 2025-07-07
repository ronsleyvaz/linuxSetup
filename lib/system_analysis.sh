#!/bin/bash

# System Analysis Library for Generic Linux Setup
# Comprehensive system analysis, reporting, and inventory management

# Strict error handling
set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/logging.sh"

# System Analysis Functions

# Generate comprehensive system inventory
generate_system_inventory() {
    local output_format="${1:-json}"
    local output_file="${2:-}"
    
    log_info "Generating comprehensive system inventory"
    
    local inventory_data=()
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Hardware Information
    local cpu_info memory_info disk_info network_info
    cpu_info=$(get_cpu_information)
    memory_info=$(get_memory_information)
    disk_info=$(get_disk_information)
    network_info=$(get_network_information)
    
    # Software Information
    local os_info package_info service_info
    os_info=$(get_os_information)
    package_info=$(get_package_information)
    service_info=$(get_service_information)
    
    # Security Information
    local security_info user_info
    security_info=$(get_security_information)
    user_info=$(get_user_information)
    
    # Performance Information
    local performance_info
    performance_info=$(get_performance_information)
    
    case "$output_format" in
        "json")
            generate_json_inventory "$timestamp" "$cpu_info" "$memory_info" "$disk_info" "$network_info" "$os_info" "$package_info" "$service_info" "$security_info" "$user_info" "$performance_info" "$output_file"
            ;;
        "csv")
            generate_csv_inventory "$timestamp" "$cpu_info" "$memory_info" "$disk_info" "$network_info" "$os_info" "$package_info" "$service_info" "$security_info" "$user_info" "$performance_info" "$output_file"
            ;;
        "html")
            generate_html_inventory "$timestamp" "$cpu_info" "$memory_info" "$disk_info" "$network_info" "$os_info" "$package_info" "$service_info" "$security_info" "$user_info" "$performance_info" "$output_file"
            ;;
        "text")
            generate_text_inventory "$timestamp" "$cpu_info" "$memory_info" "$disk_info" "$network_info" "$os_info" "$package_info" "$service_info" "$security_info" "$user_info" "$performance_info" "$output_file"
            ;;
        *)
            log_error "Unknown output format: $output_format"
            return 1
            ;;
    esac
    
    log_info "System inventory generated in $output_format format"
    return 0
}

# Get CPU information
get_cpu_information() {
    local cpu_data=()
    
    # CPU model and specs
    if [[ -f "/proc/cpuinfo" ]]; then
        local cpu_model cpu_cores cpu_threads cpu_freq
        cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
        cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
        cpu_threads=$(grep -c "^processor" /proc/cpuinfo)
        
        # Get CPU frequency
        if [[ -f "/proc/cpuinfo" ]]; then
            cpu_freq=$(grep -m1 "cpu MHz" /proc/cpuinfo | cut -d: -f2 | xargs)
        fi
        
        cpu_data+=("model:$cpu_model")
        cpu_data+=("cores:$cpu_cores")
        cpu_data+=("threads:$cpu_threads")
        cpu_data+=("frequency:${cpu_freq:-unknown}")
    fi
    
    # CPU architecture
    local cpu_arch
    cpu_arch=$(uname -m)
    cpu_data+=("architecture:$cpu_arch")
    
    # CPU usage
    local cpu_usage
    cpu_usage=$(get_cpu_usage)
    cpu_data+=("current_usage:$cpu_usage")
    
    # CPU temperature (if available)
    local cpu_temp
    cpu_temp=$(get_cpu_temperature)
    if [[ -n "$cpu_temp" ]]; then
        cpu_data+=("temperature:$cpu_temp")
    fi
    
    printf '%s\n' "${cpu_data[@]}"
}

# Get memory information
get_memory_information() {
    local memory_data=()
    
    if [[ -f "/proc/meminfo" ]]; then
        local total_mem available_mem used_mem free_mem buffers_mem cached_mem swap_total swap_used
        
        total_mem=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}')
        available_mem=$(grep "MemAvailable:" /proc/meminfo | awk '{print $2}')
        free_mem=$(grep "MemFree:" /proc/meminfo | awk '{print $2}')
        buffers_mem=$(grep "Buffers:" /proc/meminfo | awk '{print $2}')
        cached_mem=$(grep "^Cached:" /proc/meminfo | awk '{print $2}')
        swap_total=$(grep "SwapTotal:" /proc/meminfo | awk '{print $2}')
        swap_used=$(grep "SwapFree:" /proc/meminfo | awk '{print $2}')
        
        # Convert to MB
        total_mem=$((total_mem / 1024))
        available_mem=$((available_mem / 1024))
        free_mem=$((free_mem / 1024))
        buffers_mem=$((buffers_mem / 1024))
        cached_mem=$((cached_mem / 1024))
        swap_total=$((swap_total / 1024))
        swap_used=$((swap_total - swap_used / 1024))
        
        used_mem=$((total_mem - available_mem))
        
        memory_data+=("total_mb:$total_mem")
        memory_data+=("available_mb:$available_mem")
        memory_data+=("used_mb:$used_mem")
        memory_data+=("free_mb:$free_mem")
        memory_data+=("buffers_mb:$buffers_mem")
        memory_data+=("cached_mb:$cached_mem")
        memory_data+=("swap_total_mb:$swap_total")
        memory_data+=("swap_used_mb:$swap_used")
        
        # Calculate usage percentage
        local mem_usage_percent
        mem_usage_percent=$(echo "scale=2; $used_mem * 100 / $total_mem" | bc 2>/dev/null || echo "0")
        memory_data+=("usage_percent:$mem_usage_percent")
    fi
    
    printf '%s\n' "${memory_data[@]}"
}

# Get disk information
get_disk_information() {
    local disk_data=()
    
    # Disk usage by filesystem
    while IFS= read -r line; do
        if [[ "$line" =~ ^/dev/ ]]; then
            local filesystem size used avail use_percent mount_point
            read -r filesystem size used avail use_percent mount_point <<< "$line"
            
            disk_data+=("filesystem:$filesystem")
            disk_data+=("size:$size")
            disk_data+=("used:$used")
            disk_data+=("available:$avail")
            disk_data+=("use_percent:$use_percent")
            disk_data+=("mount_point:$mount_point")
        fi
    done < <(df -h 2>/dev/null | grep -v "Filesystem")
    
    # Disk devices and partitions
    if command -v lsblk &>/dev/null; then
        local block_devices
        block_devices=$(lsblk -d -n -o NAME,SIZE,TYPE,MODEL 2>/dev/null | grep -v "loop")
        while IFS= read -r device_line; do
            if [[ -n "$device_line" ]]; then
                local device_name device_size device_type device_model
                read -r device_name device_size device_type device_model <<< "$device_line"
                disk_data+=("device:$device_name")
                disk_data+=("device_size:$device_size")
                disk_data+=("device_type:$device_type")
                disk_data+=("device_model:${device_model:-unknown}")
            fi
        done <<< "$block_devices"
    fi
    
    printf '%s\n' "${disk_data[@]}"
}

# Get network information
get_network_information() {
    local network_data=()
    
    # Network interfaces
    if command -v ip &>/dev/null; then
        local interfaces
        interfaces=$(ip -o link show | grep -v "lo:" | awk '{print $2}' | tr -d ':')
        
        for interface in $interfaces; do
            local ip_addr mac_addr status
            ip_addr=$(ip -o -4 addr show "$interface" 2>/dev/null | awk '{print $4}' | cut -d'/' -f1)
            mac_addr=$(ip -o link show "$interface" 2>/dev/null | awk '{print $13}')
            status=$(ip -o link show "$interface" 2>/dev/null | grep -q "UP" && echo "up" || echo "down")
            
            network_data+=("interface:$interface")
            network_data+=("ip_address:${ip_addr:-none}")
            network_data+=("mac_address:$mac_addr")
            network_data+=("status:$status")
        done
    fi
    
    # Network connectivity
    local internet_status
    internet_status=$(check_internet_connectivity && echo "connected" || echo "disconnected")
    network_data+=("internet:$internet_status")
    
    # Hostname and DNS
    local hostname_info dns_servers
    hostname_info=$(hostname -f 2>/dev/null || hostname)
    dns_servers=$(grep "nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')
    
    network_data+=("hostname:$hostname_info")
    network_data+=("dns_servers:$dns_servers")
    
    printf '%s\n' "${network_data[@]}"
}

# Get OS information
get_os_information() {
    local os_data=()
    
    # Distribution information
    os_data+=("distribution:$DISTRO_NAME")
    os_data+=("version:$DISTRO_VERSION")
    os_data+=("codename:$DISTRO_CODENAME")
    os_data+=("family:$DISTRO_FAMILY")
    os_data+=("architecture:$DISTRO_ARCH")
    
    # Kernel information
    local kernel_version kernel_release
    kernel_version=$(uname -r)
    kernel_release=$(uname -v)
    
    os_data+=("kernel_version:$kernel_version")
    os_data+=("kernel_release:$kernel_release")
    
    # System uptime
    local uptime_info
    uptime_info=$(uptime -p 2>/dev/null || uptime | sed 's/.*up //' | sed 's/,.*user.*//')
    os_data+=("uptime:$uptime_info")
    
    # Package manager
    os_data+=("package_manager:$PACKAGE_MANAGER")
    
    # Boot time
    local boot_time
    boot_time=$(date -d "$(uptime -s 2>/dev/null || echo 'unknown')" 2>/dev/null || echo 'unknown')
    os_data+=("boot_time:$boot_time")
    
    printf '%s\n' "${os_data[@]}"
}

# Get package information
get_package_information() {
    local package_data=()
    
    # Installed packages count
    local installed_count
    case "$PACKAGE_MANAGER" in
        "apt")
            installed_count=$(dpkg -l 2>/dev/null | grep -c "^ii" || echo "0")
            ;;
        "yum"|"dnf")
            installed_count=$(rpm -qa 2>/dev/null | wc -l || echo "0")
            ;;
        "pacman")
            installed_count=$(pacman -Q 2>/dev/null | wc -l || echo "0")
            ;;
        "zypper")
            installed_count=$(rpm -qa 2>/dev/null | wc -l || echo "0")
            ;;
        *)
            installed_count="unknown"
            ;;
    esac
    
    package_data+=("installed_packages:$installed_count")
    
    # Available updates
    local updates_available
    case "$PACKAGE_MANAGER" in
        "apt")
            updates_available=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
            ;;
        "yum")
            updates_available=$(yum check-update 2>/dev/null | grep -c "updates" || echo "0")
            ;;
        "dnf")
            updates_available=$(dnf check-update 2>/dev/null | grep -c "updates" || echo "0")
            ;;
        *)
            updates_available="unknown"
            ;;
    esac
    
    package_data+=("updates_available:$updates_available")
    
    # Recently installed packages (last 30 days)
    local recent_packages
    case "$PACKAGE_MANAGER" in
        "apt")
            recent_packages=$(grep "install " /var/log/apt/history.log* 2>/dev/null | wc -l || echo "0")
            ;;
        *)
            recent_packages="unknown"
            ;;
    esac
    
    package_data+=("recent_installs:$recent_packages")
    
    printf '%s\n' "${package_data[@]}"
}

# Get service information
get_service_information() {
    local service_data=()
    
    # System services
    if command -v systemctl &>/dev/null; then
        local total_services active_services failed_services
        total_services=$(systemctl list-unit-files --type=service 2>/dev/null | grep -c "\.service" || echo "0")
        active_services=$(systemctl list-units --type=service --state=active 2>/dev/null | grep -c "\.service" || echo "0")
        failed_services=$(systemctl list-units --type=service --state=failed 2>/dev/null | grep -c "\.service" || echo "0")
        
        service_data+=("total_services:$total_services")
        service_data+=("active_services:$active_services")
        service_data+=("failed_services:$failed_services")
        
        # Critical services status
        local critical_services=("ssh" "sshd" "networking" "network" "firewall" "ufw" "docker")
        for service in "${critical_services[@]}"; do
            if systemctl is-active "$service" &>/dev/null; then
                service_data+=("${service}_status:active")
            elif systemctl list-unit-files | grep -q "^${service}\.service"; then
                service_data+=("${service}_status:inactive")
            else
                service_data+=("${service}_status:not_installed")
            fi
        done
    fi
    
    # Process count
    local process_count
    process_count=$(ps aux 2>/dev/null | wc -l || echo "0")
    service_data+=("running_processes:$process_count")
    
    printf '%s\n' "${service_data[@]}"
}

# Get security information
get_security_information() {
    local security_data=()
    
    # Firewall status
    local firewall_status
    if command -v ufw &>/dev/null; then
        firewall_status=$(ufw status 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
    elif command -v firewalld &>/dev/null; then
        firewall_status=$(firewall-cmd --state 2>/dev/null || echo "unknown")
    else
        firewall_status="not_installed"
    fi
    security_data+=("firewall_status:$firewall_status")
    
    # SSH configuration
    if [[ -f "/etc/ssh/sshd_config" ]]; then
        local ssh_root_login ssh_password_auth ssh_port
        ssh_root_login=$(grep -i "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}' || echo "unknown")
        ssh_password_auth=$(grep -i "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}' || echo "unknown")
        ssh_port=$(grep -i "^Port" /etc/ssh/sshd_config | awk '{print $2}' || echo "22")
        
        security_data+=("ssh_root_login:${ssh_root_login,,}")
        security_data+=("ssh_password_auth:${ssh_password_auth,,}")
        security_data+=("ssh_port:$ssh_port")
    fi
    
    # SELinux status (if available)
    if command -v getenforce &>/dev/null; then
        local selinux_status
        selinux_status=$(getenforce 2>/dev/null || echo "unknown")
        security_data+=("selinux_status:${selinux_status,,}")
    fi
    
    # AppArmor status (if available)
    if command -v aa-status &>/dev/null; then
        local apparmor_status
        apparmor_status=$(aa-status --enabled 2>/dev/null && echo "enabled" || echo "disabled")
        security_data+=("apparmor_status:$apparmor_status")
    fi
    
    # fail2ban status
    if command -v fail2ban-client &>/dev/null; then
        local fail2ban_status
        fail2ban_status=$(systemctl is-active fail2ban 2>/dev/null || echo "not_running")
        security_data+=("fail2ban_status:$fail2ban_status")
    fi
    
    printf '%s\n' "${security_data[@]}"
}

# Get user information
get_user_information() {
    local user_data=()
    
    # User counts
    local total_users shell_users system_users
    total_users=$(getent passwd | wc -l)
    shell_users=$(getent passwd | grep -E "(bash|sh|zsh|fish)" | wc -l)
    system_users=$(getent passwd | awk -F: '$3 < 1000 {print $1}' | wc -l)
    
    user_data+=("total_users:$total_users")
    user_data+=("shell_users:$shell_users")
    user_data+=("system_users:$system_users")
    
    # Sudo users
    local sudo_users_count
    sudo_users_count=$(getent group sudo 2>/dev/null | cut -d: -f4 | tr ',' '\n' | wc -l || echo "0")
    if [[ "$sudo_users_count" -eq 0 ]]; then
        sudo_users_count=$(getent group wheel 2>/dev/null | cut -d: -f4 | tr ',' '\n' | wc -l || echo "0")
    fi
    user_data+=("sudo_users:$sudo_users_count")
    
    # Current user
    local current_user current_groups
    current_user=$(whoami)
    current_groups=$(groups "$current_user" 2>/dev/null | cut -d: -f2 | tr ' ' ',' || echo "unknown")
    
    user_data+=("current_user:$current_user")
    user_data+=("current_groups:$current_groups")
    
    printf '%s\n' "${user_data[@]}"
}

# Get performance information
get_performance_information() {
    local performance_data=()
    
    # Load averages
    local load_1min load_5min load_15min
    read -r load_1min load_5min load_15min _ < /proc/loadavg
    
    performance_data+=("load_1min:$load_1min")
    performance_data+=("load_5min:$load_5min")
    performance_data+=("load_15min:$load_15min")
    
    # CPU usage
    local cpu_usage
    cpu_usage=$(get_cpu_usage)
    performance_data+=("cpu_usage_percent:$cpu_usage")
    
    # Memory usage
    local memory_usage
    memory_usage=$(get_memory_usage)
    performance_data+=("memory_usage_percent:$memory_usage")
    
    # Disk I/O (if available)
    if [[ -f "/proc/diskstats" ]]; then
        local disk_read_ops disk_write_ops
        disk_read_ops=$(awk '{sum += $4} END {print sum}' /proc/diskstats 2>/dev/null || echo "0")
        disk_write_ops=$(awk '{sum += $8} END {print sum}' /proc/diskstats 2>/dev/null || echo "0")
        
        performance_data+=("disk_read_ops:$disk_read_ops")
        performance_data+=("disk_write_ops:$disk_write_ops")
    fi
    
    # Network traffic (if available)
    if [[ -f "/proc/net/dev" ]]; then
        local rx_bytes tx_bytes
        rx_bytes=$(awk '/eth0:/ {print $2}' /proc/net/dev 2>/dev/null || echo "0")
        tx_bytes=$(awk '/eth0:/ {print $10}' /proc/net/dev 2>/dev/null || echo "0")
        
        performance_data+=("network_rx_bytes:$rx_bytes")
        performance_data+=("network_tx_bytes:$tx_bytes")
    fi
    
    printf '%s\n' "${performance_data[@]}"
}

# Generate JSON format inventory
generate_json_inventory() {
    local timestamp="$1"
    shift
    local output_file="$1"
    
    local json_output="{\"timestamp\":\"$timestamp\",\"system_inventory\":{"
    
    # Process each data section
    local sections=("cpu" "memory" "disk" "network" "os" "packages" "services" "security" "users" "performance")
    local section_data=("$@")
    
    for i in "${!sections[@]}"; do
        local section="${sections[$i]}"
        local data="${section_data[$i]}"
        
        json_output+="\n\"$section\":{"
        
        local first_item=true
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local key="${line%%:*}"
                local value="${line#*:}"
                
                if [[ "$first_item" == true ]]; then
                    first_item=false
                else
                    json_output+=","
                fi
                
                json_output+="\n\"$key\":\"$value\""
            fi
        done <<< "$data"
        
        json_output+="\n}"
        
        if [[ $i -lt $((${#sections[@]} - 1)) ]]; then
            json_output+=","
        fi
    done
    
    json_output+="\n}}"
    
    if [[ -n "$output_file" ]]; then
        echo -e "$json_output" > "$output_file"
    else
        echo -e "$json_output"
    fi
}

# Helper functions
get_cpu_usage() {
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' 2>/dev/null || echo "0")
    echo "$cpu_usage"
}

get_memory_usage() {
    local memory_usage
    memory_usage=$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}' 2>/dev/null || echo "0")
    echo "$memory_usage"
}

get_cpu_temperature() {
    local temp=""
    
    # Try different temperature sources
    if [[ -f "/sys/class/thermal/thermal_zone0/temp" ]]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        if [[ -n "$temp" && "$temp" -gt 0 ]]; then
            temp=$((temp / 1000))
            echo "${temp}°C"
            return 0
        fi
    fi
    
    # Try sensors command
    if command -v sensors &>/dev/null; then
        temp=$(sensors 2>/dev/null | grep -i "core 0" | grep -o "[0-9.]*°C" | head -1)
        if [[ -n "$temp" ]]; then
            echo "$temp"
            return 0
        fi
    fi
    
    # Try vcgencmd for Raspberry Pi
    if command -v vcgencmd &>/dev/null; then
        temp=$(vcgencmd measure_temp 2>/dev/null | cut -d'=' -f2)
        if [[ -n "$temp" ]]; then
            echo "$temp"
            return 0
        fi
    fi
    
    echo ""
}

# Export functions for use in other scripts
export -f generate_system_inventory
export -f get_cpu_information
export -f get_memory_information
export -f get_disk_information
export -f get_network_information
export -f get_os_information
export -f get_package_information
export -f get_service_information
export -f get_security_information
export -f get_user_information
export -f get_performance_information