#!/bin/bash
#
# System Health Monitoring Library for Linux Setup
# Provides comprehensive system health checking and reporting
# User Story 2.1: Real-time System Status
#

# Global variables for health monitoring
HEALTH_WARNINGS=()
HEALTH_ERRORS=()
HEALTH_INFO=()
SYSTEM_STATUS="unknown"

# Performance thresholds
CPU_LOAD_WARNING=2.0
CPU_LOAD_CRITICAL=4.0
MEMORY_WARNING=85
MEMORY_CRITICAL=95
DISK_WARNING=85
DISK_CRITICAL=95

# Function to display system information
display_system_info() {
    log_function_enter "display_system_info"
    
    echo "💻 System Information"
    echo "   🖥️  Distribution: $DISTRO_NAME $DISTRO_VERSION ($DISTRO_CODENAME)"
    echo "   🏗️  Architecture: $DISTRO_ARCHITECTURE"
    echo "   📦 Package Manager: $PACKAGE_MANAGER"
    echo "   🔧 Kernel: $(uname -r)"
    
    # Get system details
    local hostname=$(hostname)
    local uptime_info=$(uptime -p 2>/dev/null || echo "uptime unavailable")
    
    echo "   🏠 Hostname: $hostname"
    echo "   ⏱️  Uptime: $uptime_info"
    
    log_info "System info displayed: $DISTRO_NAME $DISTRO_VERSION, $DISTRO_ARCHITECTURE, $hostname"
    log_function_exit "display_system_info" 0
}

# Function to get memory information
get_memory_info() {
    if command_exists free; then
        # Parse memory info from free command
        local mem_info=$(free -m | awk 'NR==2{printf "%.1f %.1f %.1f", $3, $2, $3/$2*100}')
        echo "$mem_info"
    else
        echo "0 0 0"
    fi
}

# Function to get disk usage
get_disk_usage() {
    local path=${1:-"/"}
    if command_exists df; then
        df -h "$path" 2>/dev/null | awk 'NR==2{printf "%s %s %s", $3, $2, $5}' | sed 's/%//'
    else
        echo "0 0 0"
    fi
}

# Function to get CPU load
get_cpu_load() {
    if command_exists uptime; then
        uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//'
    else
        echo "0.0"
    fi
}

# Function to get CPU temperature (if available)
get_cpu_temperature() {
    # Try multiple methods to get temperature
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        local temp_millic=$(cat /sys/class/thermal/thermal_zone0/temp)
        echo "$((temp_millic / 1000))°C"
    elif command_exists sensors; then
        sensors 2>/dev/null | grep -i "core 0" | awk '{print $3}' | head -1
    elif command_exists vcgencmd; then
        # Raspberry Pi specific
        vcgencmd measure_temp 2>/dev/null | cut -d'=' -f2
    else
        echo "N/A"
    fi
}

# Function to display performance metrics
display_performance_metrics() {
    log_function_enter "display_performance_metrics"
    
    echo ""
    echo "📊 Performance Metrics"
    
    # Memory usage
    local mem_info=$(get_memory_info)
    local mem_used=$(echo "$mem_info" | awk '{print $1}')
    local mem_total=$(echo "$mem_info" | awk '{print $2}')
    local mem_percent=$(echo "$mem_info" | awk '{print $3}')
    
    echo "   💾 Memory: ${mem_used}M used / ${mem_total}M total (${mem_percent}%)"
    
    # Check memory thresholds
    if command_exists bc; then
        if (( $(echo "$mem_percent > $MEMORY_CRITICAL" | bc -l) )); then
            HEALTH_ERRORS+=("Memory usage critical: ${mem_percent}%")
            echo "   ⚠️  Memory usage is critical!"
        elif (( $(echo "$mem_percent > $MEMORY_WARNING" | bc -l) )); then
            HEALTH_WARNINGS+=("Memory usage high: ${mem_percent}%")
            echo "   ⚠️  Memory usage is high"
        fi
    else
        # Fallback using awk for floating point comparison
        if awk "BEGIN {exit !($mem_percent > $MEMORY_CRITICAL)}"; then
            HEALTH_ERRORS+=("Memory usage critical: ${mem_percent}%")
            echo "   ⚠️  Memory usage is critical!"
        elif awk "BEGIN {exit !($mem_percent > $MEMORY_WARNING)}"; then
            HEALTH_WARNINGS+=("Memory usage high: ${mem_percent}%")
            echo "   ⚠️  Memory usage is high"
        fi
    fi
    
    # Disk usage
    local disk_info=$(get_disk_usage "/")
    local disk_used=$(echo "$disk_info" | awk '{print $1}')
    local disk_total=$(echo "$disk_info" | awk '{print $2}')
    local disk_percent=$(echo "$disk_info" | awk '{print $3}')
    
    echo "   💿 Disk (/): ${disk_used} used / ${disk_total} total (${disk_percent}%)"
    
    # Check disk thresholds
    if [[ "$disk_percent" -gt "$DISK_CRITICAL" ]]; then
        HEALTH_ERRORS+=("Disk usage critical: ${disk_percent}%")
        echo "   ⚠️  Disk usage is critical!"
    elif [[ "$disk_percent" -gt "$DISK_WARNING" ]]; then
        HEALTH_WARNINGS+=("Disk usage high: ${disk_percent}%")
        echo "   ⚠️  Disk usage is high"
    fi
    
    # CPU load
    local cpu_load=$(get_cpu_load)
    echo "   ⚡ Load Average: $cpu_load"
    
    # Check load thresholds
    if command_exists bc; then
        if (( $(echo "$cpu_load > $CPU_LOAD_CRITICAL" | bc -l) )); then
            HEALTH_ERRORS+=("CPU load critical: $cpu_load")
            echo "   ⚠️  CPU load is critical!"
        elif (( $(echo "$cpu_load > $CPU_LOAD_WARNING" | bc -l) )); then
            HEALTH_WARNINGS+=("CPU load high: $cpu_load")
            echo "   ⚠️  CPU load is high"
        fi
    else
        # Fallback using awk for floating point comparison
        if awk "BEGIN {exit !($cpu_load > $CPU_LOAD_CRITICAL)}"; then
            HEALTH_ERRORS+=("CPU load critical: $cpu_load")
            echo "   ⚠️  CPU load is critical!"
        elif awk "BEGIN {exit !($cpu_load > $CPU_LOAD_WARNING)}"; then
            HEALTH_WARNINGS+=("CPU load high: $cpu_load")
            echo "   ⚠️  CPU load is high"
        fi
    fi
    
    # Temperature
    local temp=$(get_cpu_temperature)
    echo "   🌡️  CPU Temperature: $temp"
    
    log_info "Performance metrics: Memory ${mem_percent}%, Disk ${disk_percent}%, Load $cpu_load, Temp $temp"
    log_function_exit "display_performance_metrics" 0
}

# Function to get network interfaces and IPs
get_network_info() {
    local interfaces=()
    local ips=()
    
    # Get primary IP
    local primary_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A")
    
    # Get all network interfaces
    if command_exists ip; then
        # Modern ip command
        while read -r line; do
            local iface=$(echo "$line" | awk '{print $2}' | sed 's/://')
            local status=$(echo "$line" | grep -o "state [^ ]*" | awk '{print $2}')
            if [[ "$iface" != "lo" && "$status" == "UP" ]]; then
                interfaces+=("$iface")
                local ip=$(ip addr show "$iface" | grep -o "inet [0-9.]*" | awk '{print $2}' | head -1)
                ips+=("${ip:-N/A}")
            fi
        done < <(ip link show | grep -E "^[0-9]+:")
    else
        # Fallback to ifconfig
        interfaces+=("eth0")
        ips+=("$primary_ip")
    fi
    
    echo "${interfaces[*]}|${ips[*]}"
}

# Function to display network information
display_network_info() {
    log_function_enter "display_network_info"
    
    echo ""
    echo "🌐 Network Information"
    
    local hostname=$(hostname)
    echo "   🏠 Hostname: $hostname"
    
    # Get network interfaces
    local net_info=$(get_network_info)
    local interfaces=($(echo "$net_info" | cut -d'|' -f1))
    local ips=($(echo "$net_info" | cut -d'|' -f2))
    
    # Display interfaces and IPs
    for i in "${!interfaces[@]}"; do
        echo "   📍 ${interfaces[$i]}: ${ips[$i]}"
    done
    
    # Check internet connectivity
    echo -n "   🌍 Internet: "
    if ping -c 1 8.8.8.8 >/dev/null 2>&1 || ping -c 1 1.1.1.1 >/dev/null 2>&1; then
        echo "✅ Connected"
        HEALTH_INFO+=("Internet connectivity: OK")
    else
        echo "❌ Not Connected"
        HEALTH_WARNINGS+=("Internet connectivity: Failed")
    fi
    
    log_info "Network info displayed: hostname=$hostname, interfaces=${interfaces[*]}, ips=${ips[*]}"
    log_function_exit "display_network_info" 0
}

# Function to check service status
check_service_status() {
    local service="$1"
    local display_name="${2:-$service}"
    
    if command_exists systemctl; then
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo "✅ $display_name: Active"
            return 0
        else
            echo "❌ $display_name: Inactive"
            return 1
        fi
    else
        # Fallback for systems without systemd
        if pgrep -x "$service" >/dev/null 2>&1; then
            echo "✅ $display_name: Running"
            return 0
        else
            echo "❌ $display_name: Not Running"
            return 1
        fi
    fi
}

# Function to display service status
display_service_status() {
    echo ""
    echo "🔧 Service Status"
    
    # Simple service checks - test each one individually
    echo -n "   🔐 SSH: "
    if systemctl is-active --quiet ssh 2>/dev/null; then
        echo "✅ Active"
    else
        echo "❌ Inactive"
        HEALTH_WARNINGS+=("SSH service is not active")
    fi
    
    echo -n "   🐳 Docker: "
    if systemctl is-active --quiet docker 2>/dev/null; then
        echo "✅ Active"
    else
        echo "❌ Inactive"
    fi
    
    echo -n "   ⏰ Cron: "
    if systemctl is-active --quiet cron 2>/dev/null; then
        echo "✅ Active"
    else
        echo "❌ Inactive"
    fi
    
    echo -n "   📝 Syslog: "
    if systemctl is-active --quiet rsyslog 2>/dev/null; then
        echo "✅ Active"
    else
        echo "❌ Inactive"
    fi
    
    # Check for active processes
    echo ""
    echo "🔄 Active Processes"
    local docker_count=$(pgrep -c docker 2>/dev/null || echo "0")
    if [[ "$docker_count" -gt 0 ]]; then
        echo "   ✅ docker: $docker_count process(es)"
    fi
    
    local nginx_count=$(pgrep -c nginx 2>/dev/null || echo "0")
    nginx_count=${nginx_count:-0}
    if [[ "$nginx_count" -gt 0 ]]; then
        echo "   ✅ nginx: $nginx_count process(es)"
    fi
}

# Function to check essential tools status
display_essential_tools_status() {
    log_function_enter "display_essential_tools_status"
    
    echo ""
    echo "🛠️ Essential Tools Status"
    
    # Source tool installer to get tool categories
    if [[ -f "$LIB_DIR/tool_installer.sh" ]]; then
        source "$LIB_DIR/tool_installer.sh"
        
        local categories=$(get_tool_categories)
        local tools_checked=0
        local tools_available=0
        
        for category in $categories; do
            local tools=$(get_category_tools "$category")
            local tools_array=($tools)
            
            echo "   📦 $category:"
            for tool in "${tools_array[@]}"; do
                ((tools_checked++))
                echo -n "      "
                if is_tool_installed "$tool"; then
                    echo "✅ $tool"
                    ((tools_available++))
                else
                    echo "❌ $tool"
                fi
            done
        done
        
        echo "   📊 Summary: $tools_available/$tools_checked tools available"
        
        if [[ $tools_available -eq $tools_checked ]]; then
            HEALTH_INFO+=("All essential tools are installed")
        elif [[ $tools_available -gt $((tools_checked * 80 / 100)) ]]; then
            HEALTH_INFO+=("Most essential tools are installed ($tools_available/$tools_checked)")
        else
            HEALTH_WARNINGS+=("Many essential tools are missing ($tools_available/$tools_checked)")
        fi
    else
        echo "   ⚠️  Tool installer library not found"
    fi
    
    log_function_exit "display_essential_tools_status" 0
}

# Function to check security status
display_security_status() {
    log_function_enter "display_security_status"
    
    echo ""
    echo "🔒 Security Status"
    
    # Check firewall status
    echo -n "   🔥 Firewall: "
    if command_exists ufw; then
        if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
            echo "✅ UFW Active"
            HEALTH_INFO+=("UFW firewall is active")
        else
            echo "❌ UFW Inactive"
            HEALTH_WARNINGS+=("UFW firewall is inactive")
        fi
    elif command_exists firewalld; then
        if systemctl is-active --quiet firewalld; then
            echo "✅ Firewalld Active"
            HEALTH_INFO+=("Firewalld is active")
        else
            echo "❌ Firewalld Inactive"
            HEALTH_WARNINGS+=("Firewalld is inactive")
        fi
    else
        echo "❌ No firewall detected"
        HEALTH_WARNINGS+=("No firewall detected")
    fi
    
    # Check SSH configuration
    echo -n "   🔐 SSH: "
    if [[ -f /etc/ssh/sshd_config ]]; then
        if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd; then
            echo "✅ SSH Active"
            
            # Check for common security settings
            if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
                echo "      ✅ Root login disabled"
                HEALTH_INFO+=("SSH root login is disabled")
            else
                echo "      ⚠️  Root login may be enabled"
                HEALTH_WARNINGS+=("SSH root login may be enabled")
            fi
        else
            echo "❌ SSH Inactive"
            HEALTH_WARNINGS+=("SSH service is inactive")
        fi
    else
        echo "❌ SSH not configured"
        HEALTH_WARNINGS+=("SSH is not configured")
    fi
    
    # Check for automatic updates
    echo -n "   🔄 Auto Updates: "
    if command_exists unattended-upgrades; then
        if systemctl is-active --quiet unattended-upgrades; then
            echo "✅ Enabled"
            HEALTH_INFO+=("Automatic updates are enabled")
        else
            echo "❌ Disabled"
            HEALTH_WARNINGS+=("Automatic updates are disabled")
        fi
    else
        echo "❌ Not configured"
        HEALTH_WARNINGS+=("Automatic updates are not configured")
    fi
    
    log_function_exit "display_security_status" 0
}

# Function to detect system issues
detect_system_issues() {
    log_function_enter "detect_system_issues"
    
    echo ""
    echo "🔍 System Issues Detection"
    
    # Check for common issues
    local issues_found=0
    
    # Check available disk space
    local disk_percent=$(get_disk_usage "/" | awk '{print $3}')
    if [[ "$disk_percent" -gt 95 ]]; then
        echo "   ❌ Critical: Disk space very low (${disk_percent}%)"
        HEALTH_ERRORS+=("Disk space critically low: ${disk_percent}%")
        ((issues_found++))
    fi
    
    # Check for recent errors in syslog
    if [[ -f /var/log/syslog ]]; then
        local recent_errors=$(tail -n 100 /var/log/syslog | grep -i "error\|fail\|critical" | wc -l)
        if [[ "$recent_errors" -gt 10 ]]; then
            echo "   ⚠️  Warning: ${recent_errors} recent errors in syslog"
            HEALTH_WARNINGS+=("${recent_errors} recent errors in system log")
            ((issues_found++))
        fi
    fi
    
    # Check for failed systemd services
    if command_exists systemctl; then
        local failed_services=$(systemctl list-units --failed --no-legend 2>/dev/null | wc -l)
        if [[ "$failed_services" -gt 0 ]]; then
            echo "   ⚠️  Warning: $failed_services failed systemd services"
            HEALTH_WARNINGS+=("$failed_services failed systemd services")
            ((issues_found++))
        fi
    fi
    
    # Check for high load average
    local load_avg=$(get_cpu_load)
    if command_exists bc; then
        if (( $(echo "$load_avg > 5.0" | bc -l) )); then
            echo "   ⚠️  Warning: Very high load average ($load_avg)"
            HEALTH_WARNINGS+=("Very high load average: $load_avg")
            ((issues_found++))
        fi
    else
        if awk "BEGIN {exit !($load_avg > 5.0)}"; then
            echo "   ⚠️  Warning: Very high load average ($load_avg)"
            HEALTH_WARNINGS+=("Very high load average: $load_avg")
            ((issues_found++))
        fi
    fi
    
    if [[ $issues_found -eq 0 ]]; then
        echo "   ✅ No critical issues detected"
        HEALTH_INFO+=("No critical system issues detected")
    else
        echo "   📊 $issues_found system issues found"
    fi
    
    log_info "System issues detection completed: $issues_found issues found"
    log_function_exit "detect_system_issues" 0
}

# Function to get overall system status
get_overall_system_status() {
    local error_count=${#HEALTH_ERRORS[@]}
    local warning_count=${#HEALTH_WARNINGS[@]}
    
    if [[ $error_count -gt 0 ]]; then
        echo "❌ CRITICAL ($error_count errors, $warning_count warnings)"
        SYSTEM_STATUS="critical"
    elif [[ $warning_count -gt 3 ]]; then
        echo "⚠️  WARNING ($warning_count warnings)"
        SYSTEM_STATUS="warning"
    elif [[ $warning_count -gt 0 ]]; then
        echo "⚠️  MINOR ISSUES ($warning_count warnings)"
        SYSTEM_STATUS="minor_issues"
    else
        echo "✅ HEALTHY"
        SYSTEM_STATUS="healthy"
    fi
}

# Function to generate system report
generate_system_report() {
    log_function_enter "generate_system_report"
    
    local report_file="$LOG_DIR/system-health-report-$(date +%Y%m%d-%H%M%S).txt"
    
    echo ""
    echo "📋 Generating System Report"
    echo "   📄 Report file: $report_file"
    
    {
        echo "=========================================================================="
        echo "Linux System Health Report"
        echo "=========================================================================="
        echo "Generated: $(date)"
        echo "System: $DISTRO_NAME $DISTRO_VERSION ($DISTRO_ARCHITECTURE)"
        echo "Hostname: $(hostname)"
        echo "=========================================================================="
        echo ""
        
        echo "SYSTEM STATUS: $(get_overall_system_status)"
        echo ""
        
        if [[ ${#HEALTH_ERRORS[@]} -gt 0 ]]; then
            echo "ERRORS:"
            for error in "${HEALTH_ERRORS[@]}"; do
                echo "  - $error"
            done
            echo ""
        fi
        
        if [[ ${#HEALTH_WARNINGS[@]} -gt 0 ]]; then
            echo "WARNINGS:"
            for warning in "${HEALTH_WARNINGS[@]}"; do
                echo "  - $warning"
            done
            echo ""
        fi
        
        if [[ ${#HEALTH_INFO[@]} -gt 0 ]]; then
            echo "INFORMATION:"
            for info in "${HEALTH_INFO[@]}"; do
                echo "  - $info"
            done
            echo ""
        fi
        
        echo "PERFORMANCE METRICS:"
        echo "  - Memory: $(get_memory_info | awk '{printf "%.1fM used / %.1fM total (%.1f%%)", $1, $2, $3}')"
        echo "  - Disk: $(get_disk_usage "/" | awk '{printf "%s used / %s total (%s%%)", $1, $2, $3}')"
        echo "  - Load: $(get_cpu_load)"
        echo "  - Temperature: $(get_cpu_temperature)"
        echo ""
        
        echo "NETWORK:"
        local net_info=$(get_network_info)
        local interfaces=($(echo "$net_info" | cut -d'|' -f1))
        local ips=($(echo "$net_info" | cut -d'|' -f2))
        for i in "${!interfaces[@]}"; do
            echo "  - ${interfaces[$i]}: ${ips[$i]}"
        done
        echo ""
        
        echo "=========================================================================="
        echo "Report generated by Generic Linux Setup & Monitoring System"
        echo "=========================================================================="
        
    } > "$report_file"
    
    print_status "success" "System report generated: $report_file"
    log_info "System report generated: $report_file"
    log_function_exit "generate_system_report" 0
}

# Function to export JSON report
export_json_report() {
    log_function_enter "export_json_report"
    
    local json_file="$LOG_DIR/system-health-$(date +%Y%m%d-%H%M%S).json"
    
    echo "   📄 JSON report: $json_file"
    
    # Get performance metrics
    local mem_info=$(get_memory_info)
    local disk_info=$(get_disk_usage "/")
    local cpu_load=$(get_cpu_load)
    local cpu_temp=$(get_cpu_temperature)
    
    # Get network info
    local net_info=$(get_network_info)
    local interfaces=($(echo "$net_info" | cut -d'|' -f1))
    local ips=($(echo "$net_info" | cut -d'|' -f2))
    
    cat > "$json_file" << EOF
{
  "system_health_report": {
    "timestamp": "$(date -Iseconds)",
    "system": {
      "distribution": "$DISTRO_NAME",
      "version": "$DISTRO_VERSION",
      "codename": "$DISTRO_CODENAME",
      "architecture": "$DISTRO_ARCHITECTURE",
      "hostname": "$(hostname)",
      "kernel": "$(uname -r)",
      "uptime": "$(uptime -p 2>/dev/null || echo 'unavailable')"
    },
    "status": {
      "overall": "$SYSTEM_STATUS",
      "errors": $(printf '"%s",' "${HEALTH_ERRORS[@]}" | sed 's/,$//' | sed 's/^/[/' | sed 's/$/]/'),
      "warnings": $(printf '"%s",' "${HEALTH_WARNINGS[@]}" | sed 's/,$//' | sed 's/^/[/' | sed 's/$/]/'),
      "info": $(printf '"%s",' "${HEALTH_INFO[@]}" | sed 's/,$//' | sed 's/^/[/' | sed 's/$/]/')
    },
    "performance": {
      "memory": {
        "used_mb": $(echo "$mem_info" | awk '{print $1}'),
        "total_mb": $(echo "$mem_info" | awk '{print $2}'),
        "percent": $(echo "$mem_info" | awk '{print $3}')
      },
      "disk": {
        "used": "$(echo "$disk_info" | awk '{print $1}')",
        "total": "$(echo "$disk_info" | awk '{print $2}')",
        "percent": $(echo "$disk_info" | awk '{print $3}')
      },
      "load_average": "$cpu_load",
      "temperature": "$cpu_temp"
    },
    "network": {
      "interfaces": $(printf '"%s",' "${interfaces[@]}" | sed 's/,$//' | sed 's/^/[/' | sed 's/$/]/'),
      "ip_addresses": $(printf '"%s",' "${ips[@]}" | sed 's/,$//' | sed 's/^/[/' | sed 's/$/]/'),
      "internet_connectivity": $((ping -c 1 8.8.8.8 >/dev/null 2>&1 || ping -c 1 1.1.1.1 >/dev/null 2>&1) && echo "true" || echo "false")
    }
  }
}
EOF
    
    print_status "success" "JSON report exported: $json_file"
    log_info "JSON report exported: $json_file"
    log_function_exit "export_json_report" 0
}