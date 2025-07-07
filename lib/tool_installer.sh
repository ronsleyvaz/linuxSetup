#!/bin/bash
#
# Essential Tools Installation System for Linux Setup
# Handles installation of development and system tools across distributions
#

# Global variables for tool installation
TOOL_CATEGORIES=()
TOOLS_TO_INSTALL=()
FAILED_TOOLS=()
INSTALLED_TOOLS=()
SKIPPED_TOOLS=()

# Tool installation results
TOTAL_TOOLS=0
SUCCESSFUL_INSTALLS=0
FAILED_INSTALLS=0
SKIPPED_INSTALLS=0

# Function to get tool category data (replacing associative arrays for better compatibility)
get_category_data() {
    local category="$1"
    local field="$2"
    
    case "$category" in
        "CORE_DEVELOPMENT")
            case "$field" in
                "tools") echo "git vim curl wget" ;;
                "description") echo "Core development tools for coding and version control" ;;
                "priority") echo "high" ;;
                "batch_size") echo "4" ;;
            esac
            ;;
        "BUILD_TOOLS")
            case "$field" in
                "tools") echo "build-essential" ;;
                "description") echo "Compilation and build tools" ;;
                "priority") echo "high" ;;
                "batch_size") echo "1" ;;
            esac
            ;;
        "TERMINAL_TOOLS")
            case "$field" in
                "tools") echo "screen tmux tree htop iotop" ;;
                "description") echo "Terminal multiplexers and system monitoring" ;;
                "priority") echo "high" ;;
                "batch_size") echo "5" ;;
            esac
            ;;
        "NETWORK_TOOLS")
            case "$field" in
                "tools") echo "nmap tcpdump rsync netcat-openbsd" ;;
                "description") echo "Network analysis and transfer tools" ;;
                "priority") echo "medium" ;;
                "batch_size") echo "4" ;;
            esac
            ;;
        "ARCHIVE_TOOLS")
            case "$field" in
                "tools") echo "zip unzip tar gzip" ;;
                "description") echo "Archive and compression utilities" ;;
                "priority") echo "medium" ;;
                "batch_size") echo "4" ;;
            esac
            ;;
        "PRODUCTIVITY_TOOLS")
            case "$field" in
                "tools") echo "fzf bat jq" ;;
                "description") echo "Productivity and text processing tools" ;;
                "priority") echo "medium" ;;
                "batch_size") echo "3" ;;
            esac
            ;;
        "SYSTEM_MONITORING")
            case "$field" in
                "tools") echo "lsof strace" ;;
                "description") echo "System monitoring and debugging tools" ;;
                "priority") echo "low" ;;
                "batch_size") echo "2" ;;
            esac
            ;;
    esac
}

# Function to get tool categories
get_tool_categories() {
    echo "CORE_DEVELOPMENT BUILD_TOOLS TERMINAL_TOOLS NETWORK_TOOLS ARCHIVE_TOOLS PRODUCTIVITY_TOOLS SYSTEM_MONITORING"
}

# Function to get tools for a category
get_category_tools() {
    local category="$1"
    get_category_data "$category" "tools"
}

# Function to get category description
get_category_description() {
    local category="$1"
    get_category_data "$category" "description"
}

# Function to get category priority
get_category_priority() {
    local category="$1"
    get_category_data "$category" "priority"
}

# Function to get category batch size
get_category_batch_size() {
    local category="$1"
    get_category_data "$category" "batch_size"
}

# Function to get distribution-specific package name
get_distribution_package_name() {
    local generic_name="$1"
    
    case "$PACKAGE_MANAGER" in
        "apt"|"apt-get")
            case "$generic_name" in
                "build-essential") echo "build-essential" ;;
                "netcat-openbsd") echo "netcat-openbsd" ;;
                "fzf") echo "fzf" ;;
                "bat") echo "bat" ;;
                "jq") echo "jq" ;;
                "tcpdump") echo "tcpdump" ;;
                "nmap") echo "nmap" ;;
                "lsof") echo "lsof" ;;
                "strace") echo "strace" ;;
                *) echo "$generic_name" ;;
            esac
            ;;
        "dnf"|"yum")
            case "$generic_name" in
                "build-essential") echo "gcc gcc-c++ make automake autoconf" ;;
                "netcat-openbsd") echo "nc" ;;
                "fzf") echo "fzf" ;;
                "bat") echo "bat" ;;
                "jq") echo "jq" ;;
                "tcpdump") echo "tcpdump" ;;
                "nmap") echo "nmap" ;;
                "lsof") echo "lsof" ;;
                "strace") echo "strace" ;;
                *) echo "$generic_name" ;;
            esac
            ;;
        "pacman")
            case "$generic_name" in
                "build-essential") echo "base-devel" ;;
                "netcat-openbsd") echo "openbsd-netcat" ;;
                "fzf") echo "fzf" ;;
                "bat") echo "bat" ;;
                "jq") echo "jq" ;;
                "tcpdump") echo "tcpdump" ;;
                "nmap") echo "nmap" ;;
                "lsof") echo "lsof" ;;
                "strace") echo "strace" ;;
                *) echo "$generic_name" ;;
            esac
            ;;
        "zypper")
            case "$generic_name" in
                "build-essential") echo "pattern:devel_basis" ;;
                "netcat-openbsd") echo "netcat-openbsd" ;;
                "fzf") echo "fzf" ;;
                "bat") echo "bat" ;;
                "jq") echo "jq" ;;
                "tcpdump") echo "tcpdump" ;;
                "nmap") echo "nmap" ;;
                "lsof") echo "lsof" ;;
                "strace") echo "strace" ;;
                *) echo "$generic_name" ;;
            esac
            ;;
        "apk")
            case "$generic_name" in
                "build-essential") echo "build-base" ;;
                "netcat-openbsd") echo "netcat-openbsd" ;;
                "fzf") echo "fzf" ;;
                "bat") echo "bat" ;;
                "jq") echo "jq" ;;
                "tcpdump") echo "tcpdump" ;;
                "nmap") echo "nmap" ;;
                "lsof") echo "lsof" ;;
                "strace") echo "strace" ;;
                *) echo "$generic_name" ;;
            esac
            ;;
        *)
            echo "$generic_name"
            ;;
    esac
}

# Function to check if tool is already installed
is_tool_installed() {
    local tool="$1"
    local package_name=$(get_distribution_package_name "$tool")
    
    # Special cases for tools with different command names
    case "$tool" in
        "build-essential")
            if [[ "$PACKAGE_MANAGER" =~ ^(dnf|yum)$ ]]; then
                command_exists gcc
            else
                is_package_installed "$package_name"
            fi
            ;;
        "netcat-openbsd"|"netcat")
            command_exists nc || command_exists netcat
            ;;
        *)
            # For most tools, check if command exists
            command_exists "$tool"
            ;;
    esac
}

# Function to install a single tool with verification
install_tool_with_verification() {
    local tool="$1"
    local package_name=$(get_distribution_package_name "$tool")
    
    log_function_enter "install_tool_with_verification"
    log_info "Installing tool: $tool (package: $package_name)"
    
    # Check if already installed
    if is_tool_installed "$tool"; then
        print_status "info" "$tool is already installed"
        log_info "Tool $tool is already installed, skipping"
        SKIPPED_TOOLS+=("$tool")
        ((SKIPPED_INSTALLS++))
        log_function_exit "install_tool_with_verification" 0
        return 0
    fi
    
    # Install the package
    print_status "progress" "Installing $tool..."
    
    if install_package "$package_name" "Installing $tool"; then
        # Verify installation
        if is_tool_installed "$tool"; then
            print_status "success" "$tool installed successfully"
            log_info "Tool $tool installed and verified"
            INSTALLED_TOOLS+=("$tool")
            ((SUCCESSFUL_INSTALLS++))
            log_function_exit "install_tool_with_verification" 0
            return 0
        else
            print_status "warning" "$tool package installed but command not available"
            log_warn "Tool $tool package installed but verification failed"
            FAILED_TOOLS+=("$tool")
            ((FAILED_INSTALLS++))
            log_function_exit "install_tool_with_verification" 1
            return 1
        fi
    else
        print_status "error" "Failed to install $tool"
        log_error "Failed to install tool $tool"
        FAILED_TOOLS+=("$tool")
        ((FAILED_INSTALLS++))
        log_function_exit "install_tool_with_verification" 1
        return 1
    fi
}

# Function to install tools in batch with error recovery
install_tools_batch_with_recovery() {
    local tools_array=("$@")
    local batch_size=${#tools_array[@]}
    
    log_function_enter "install_tools_batch_with_recovery"
    log_info "Installing batch of $batch_size tools: ${tools_array[*]}"
    
    # Convert tools to package names
    local packages=()
    
    for tool in "${tools_array[@]}"; do
        local package_name=$(get_distribution_package_name "$tool")
        packages+=("$package_name")
    done
    
    # Try batch installation first
    print_status "progress" "Attempting batch installation of ${#tools_array[@]} tools..."
    log_info "Batch packages: ${packages[*]}"
    
    local batch_command="sudo $PACKAGE_MANAGER_INSTALL_CMD ${packages[*]}"
    
    if log_command "$batch_command" "Batch install tools"; then
        print_status "success" "Batch installation completed"
        log_info "Batch installation successful"
        
        # Verify each tool in the batch
        local batch_verified=0
        for tool in "${tools_array[@]}"; do
            if is_tool_installed "$tool"; then
                INSTALLED_TOOLS+=("$tool")
                ((SUCCESSFUL_INSTALLS++))
                ((batch_verified++))
                log_info "Tool $tool verified after batch install"
            else
                FAILED_TOOLS+=("$tool")
                ((FAILED_INSTALLS++))
                log_warn "Tool $tool not verified after batch install"
            fi
        done
        
        print_status "info" "Batch verification: $batch_verified/${#tools_array[@]} tools working"
    else
        print_status "warning" "Batch installation failed, trying individual installations..."
        log_warn "Batch installation failed, falling back to individual installs"
        
        # Fall back to individual installation
        for tool in "${tools_array[@]}"; do
            install_tool_with_verification "$tool"
        done
    fi
    
    log_function_exit "install_tools_batch_with_recovery" 0
    return 0
}

# Function to install tools by category
install_category_tools() {
    local category="$1"
    local tools=$(get_category_tools "$category")
    local description=$(get_category_description "$category")
    local batch_size=$(get_category_batch_size "$category")
    
    log_function_enter "install_category_tools"
    log_info "Installing category: $category"
    log_info "Tools: $tools"
    log_info "Description: $description"
    log_info "Batch size: $batch_size"
    
    print_status "info" "Installing $category"
    print_status "info" "Description: $description"
    
    # Convert tools string to array
    local tools_array=($tools)
    local category_total=${#tools_array[@]}
    local category_start_success=$SUCCESSFUL_INSTALLS
    
    # Check if any tools are already installed
    local tools_to_install=()
    local already_installed=()
    
    for tool in "${tools_array[@]}"; do
        if is_tool_installed "$tool"; then
            already_installed+=("$tool")
            SKIPPED_TOOLS+=("$tool")
            ((SKIPPED_INSTALLS++))
            print_status "info" "$tool is already installed"
            log_info "Tool $tool already installed, skipping"
        else
            tools_to_install+=("$tool")
        fi
    done
    
    # Install remaining tools
    if [[ ${#tools_to_install[@]} -gt 0 ]]; then
        # Decide between batch and individual installation
        if [[ ${#tools_to_install[@]} -le $batch_size && ${#tools_to_install[@]} -gt 1 ]]; then
            install_tools_batch_with_recovery "${tools_to_install[@]}"
        else
            # Install individually for large categories or single tools
            for tool in "${tools_to_install[@]}"; do
                install_tool_with_verification "$tool"
            done
        fi
    fi
    
    # Category summary
    local category_success=$((SUCCESSFUL_INSTALLS - category_start_success))
    local category_skipped=${#already_installed[@]}
    
    print_status "info" "Category $category: $category_success new, $category_skipped existing, ${#tools_to_install[@]} attempted"
    log_info "Category $category completed: $category_success/$category_total successful installs"
    
    log_function_exit "install_category_tools" 0
    return 0
}

# Function to install tools by priority
install_tools_by_priority() {
    local priority="$1"
    
    log_function_enter "install_tools_by_priority"
    log_info "Installing tools with priority: $priority"
    
    print_status "progress" "Installing $priority priority tools..."
    
    local categories=$(get_tool_categories)
    for category in $categories; do
        local cat_priority=$(get_category_priority "$category")
        if [[ "$cat_priority" == "$priority" ]]; then
            install_category_tools "$category"
        fi
    done
    
    log_function_exit "install_tools_by_priority" 0
}

# Function to install all essential tools
install_essential_tools() {
    log_function_enter "install_essential_tools"
    log_info "Starting essential tools installation"
    
    # Reset counters
    FAILED_TOOLS=()
    INSTALLED_TOOLS=()
    SKIPPED_TOOLS=()
    TOTAL_TOOLS=0
    SUCCESSFUL_INSTALLS=0
    FAILED_INSTALLS=0
    SKIPPED_INSTALLS=0
    
    # Count total tools
    local categories=$(get_tool_categories)
    for category in $categories; do
        local tools=$(get_category_tools "$category")
        local tools_array=($tools)
        TOTAL_TOOLS=$((TOTAL_TOOLS + ${#tools_array[@]}))
    done
    
    log_info "Total tools to install: $TOTAL_TOOLS"
    
    print_status "progress" "Installing $TOTAL_TOOLS essential tools..."
    
    # Update package lists first
    print_status "progress" "Updating package lists..."
    if ! update_package_lists; then
        print_status "warning" "Failed to update package lists, continuing anyway"
        log_warn "Package list update failed, continuing with installation"
    fi
    
    # Install by priority
    install_tools_by_priority "high"
    install_tools_by_priority "medium"
    install_tools_by_priority "low"
    
    # Generate summary
    print_installation_summary
    
    log_info "Essential tools installation completed"
    log_info "Results: $SUCCESSFUL_INSTALLS successful, $FAILED_INSTALLS failed, $SKIPPED_INSTALLS skipped"
    
    log_function_exit "install_essential_tools" 0
    return 0
}

# Function to print installation summary
print_installation_summary() {
    echo ""
    echo "📊 Essential Tools Installation Summary"
    echo "======================================"
    echo "Total tools: $TOTAL_TOOLS"
    echo ""
    
    if [[ ${#INSTALLED_TOOLS[@]} -gt 0 ]]; then
        print_status "success" "Successfully installed (${#INSTALLED_TOOLS[@]}):"
        for tool in "${INSTALLED_TOOLS[@]}"; do
            echo "   ✅ $tool"
        done
        echo ""
    fi
    
    if [[ ${#SKIPPED_TOOLS[@]} -gt 0 ]]; then
        print_status "info" "Already installed (${#SKIPPED_TOOLS[@]}):"
        for tool in "${SKIPPED_TOOLS[@]}"; do
            echo "   ⏭️  $tool"
        done
        echo ""
    fi
    
    if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
        print_status "warning" "Failed to install (${#FAILED_TOOLS[@]}):"
        for tool in "${FAILED_TOOLS[@]}"; do
            echo "   ❌ $tool"
        done
        echo ""
    fi
    
    # Overall status
    local success_rate=$((SUCCESSFUL_INSTALLS * 100 / TOTAL_TOOLS))
    echo "📈 Success Rate: $success_rate% ($SUCCESSFUL_INSTALLS/$TOTAL_TOOLS)"
    
    if [[ $FAILED_INSTALLS -eq 0 ]]; then
        print_status "success" "All essential tools installation completed successfully!"
    elif [[ $FAILED_INSTALLS -lt 3 ]]; then
        print_status "warning" "Essential tools installation completed with minor issues"
    else
        print_status "error" "Essential tools installation completed with significant issues"
    fi
}

# Function to test tool functionality
test_tool_functionality() {
    local tool="$1"
    
    log_function_enter "test_tool_functionality"
    log_debug "Testing functionality of tool: $tool"
    
    case "$tool" in
        "git")
            if git --version >/dev/null 2>&1; then
                log_debug "Git version check: PASS"
                return 0
            fi
            ;;
        "vim")
            if vim --version >/dev/null 2>&1; then
                log_debug "Vim version check: PASS"
                return 0
            fi
            ;;
        "curl")
            if curl --version >/dev/null 2>&1; then
                log_debug "Curl version check: PASS"
                return 0
            fi
            ;;
        "build-essential"|"gcc")
            if gcc --version >/dev/null 2>&1; then
                log_debug "GCC compilation test: PASS"
                return 0
            fi
            ;;
        "fzf")
            if fzf --version >/dev/null 2>&1; then
                log_debug "FZF version check: PASS"
                return 0
            fi
            ;;
        *)
            # Generic command existence test
            if command_exists "$tool"; then
                log_debug "Tool $tool command test: PASS"
                return 0
            fi
            ;;
    esac
    
    log_debug "Tool $tool functionality test: FAIL"
    log_function_exit "test_tool_functionality" 1
    return 1
}

# Function to perform comprehensive tool verification
verify_essential_tools() {
    log_function_enter "verify_essential_tools"
    log_info "Verifying essential tools availability and functionality"
    
    print_status "progress" "Verifying installed tools..."
    
    local verified_count=0
    local functional_count=0
    local verification_failed=()
    local functionality_failed=()
    local verification_results=()
    
    local categories=$(get_tool_categories)
    for category in $categories; do
        local tools=$(get_category_tools "$category")
        local tools_array=($tools)
        
        print_status "info" "Verifying category: $category"
        
        for tool in "${tools_array[@]}"; do
            local status="❌"
            local details=""
            
            if is_tool_installed "$tool"; then
                ((verified_count++))
                status="✅"
                details="installed"
                log_debug "Tool $tool verification: PASS"
                
                # Test functionality
                if test_tool_functionality "$tool"; then
                    ((functional_count++))
                    details="installed and functional"
                    log_debug "Tool $tool functionality: PASS"
                else
                    functionality_failed+=("$tool")
                    details="installed but functionality test failed"
                    log_warn "Tool $tool functionality: FAIL"
                fi
            else
                verification_failed+=("$tool")
                details="not installed"
                log_warn "Tool $tool verification: FAIL"
            fi
            
            verification_results+=("$tool:$status:$details")
            echo "   $status $tool ($details)"
        done
        echo ""
    done
    
    # Comprehensive summary
    echo "🔍 Comprehensive Tools Verification Summary"
    echo "=========================================="
    echo "Total tools checked: $TOTAL_TOOLS"
    echo "Available tools: $verified_count/$TOTAL_TOOLS"
    echo "Functional tools: $functional_count/$TOTAL_TOOLS"
    echo ""
    
    if [[ ${#verification_failed[@]} -gt 0 ]]; then
        print_status "warning" "Tools not installed (${#verification_failed[@]}):"
        for tool in "${verification_failed[@]}"; do
            echo "   ❌ $tool"
        done
        echo ""
    fi
    
    if [[ ${#functionality_failed[@]} -gt 0 ]]; then
        print_status "warning" "Tools with functionality issues (${#functionality_failed[@]}):"
        for tool in "${functionality_failed[@]}"; do
            echo "   ⚠️  $tool"
        done
        echo ""
    fi
    
    # Overall assessment
    local success_rate=$((verified_count * 100 / TOTAL_TOOLS))
    local functionality_rate=$((functional_count * 100 / TOTAL_TOOLS))
    
    echo "📊 Verification Rates:"
    echo "   Installation: $success_rate%"
    echo "   Functionality: $functionality_rate%"
    echo ""
    
    if [[ $verified_count -eq $TOTAL_TOOLS && $functional_count -eq $TOTAL_TOOLS ]]; then
        print_status "success" "All essential tools are installed and functional!"
    elif [[ $verified_count -eq $TOTAL_TOOLS ]]; then
        print_status "warning" "All tools installed but some functionality issues detected"
    elif [[ $success_rate -ge 80 ]]; then
        print_status "warning" "Most tools installed successfully"
    else
        print_status "error" "Significant tool installation issues detected"
    fi
    
    log_info "Tools verification completed: $verified_count/$TOTAL_TOOLS installed, $functional_count/$TOTAL_TOOLS functional"
    log_function_exit "verify_essential_tools" 0
    return 0
}

# Function to generate detailed installation report
generate_installation_report() {
    local report_file="$LOG_DIR/installation-report-$(date +%Y%m%d-%H%M%S).json"
    
    log_function_enter "generate_installation_report"
    log_info "Generating installation report: $report_file"
    
    cat > "$report_file" << EOF
{
  "installation_report": {
    "timestamp": "$(date -Iseconds)",
    "system": {
      "distribution": "$DISTRO_NAME",
      "version": "$DISTRO_VERSION",
      "architecture": "$DISTRO_ARCHITECTURE",
      "package_manager": "$PACKAGE_MANAGER"
    },
    "summary": {
      "total_tools": $TOTAL_TOOLS,
      "successful_installs": $SUCCESSFUL_INSTALLS,
      "failed_installs": $FAILED_INSTALLS,
      "skipped_installs": $SKIPPED_INSTALLS,
      "success_rate": $((SUCCESSFUL_INSTALLS * 100 / TOTAL_TOOLS))
    },
    "installed_tools": [
$(printf '      "%s"' "${INSTALLED_TOOLS[@]}" | sed 's/$/,/' | sed '$s/,$//')
    ],
    "failed_tools": [
$(printf '      "%s"' "${FAILED_TOOLS[@]}" | sed 's/$/,/' | sed '$s/,$//')
    ],
    "skipped_tools": [
$(printf '      "%s"' "${SKIPPED_TOOLS[@]}" | sed 's/$/,/' | sed '$s/,$//')
    ]
  }
}
EOF
    
    print_status "info" "Installation report saved: $report_file"
    log_info "Installation report generated: $report_file"
    log_function_exit "generate_installation_report" 0
    return 0
}

# Function to list available tools by category
list_tool_categories() {
    echo "📋 Available Tool Categories"
    echo "=========================="
    
    local categories=$(get_tool_categories)
    for category in $categories; do
        local tools=$(get_category_tools "$category")
        local description=$(get_category_description "$category")
        local priority=$(get_category_priority "$category")
        
        echo ""
        echo "📦 $category ($priority priority)"
        echo "   Description: $description"
        echo "   Tools: $tools"
    done
}

# Function to install specific tool category
install_specific_category() {
    local category="$1"
    
    if [[ -z "$category" ]]; then
        log_error "No category specified for installation"
        return 1
    fi
    
    # Validate category exists
    local categories=$(get_tool_categories)
    local category_found=false
    for cat in $categories; do
        if [[ "$cat" == "$category" ]]; then
            category_found=true
            break
        fi
    done
    
    if [[ "$category_found" == false ]]; then
        log_error "Invalid category: $category"
        echo "Available categories: $categories"
        return 1
    fi
    
    log_info "Installing specific category: $category"
    
    # Update package lists
    update_package_lists
    
    # Install the category
    install_category_tools "$category"
    
    # Print summary for this category
    echo ""
    echo "📊 Category Installation Summary: $category"
    echo "========================================"
    print_installation_summary
    
    return 0
}

# Function to get installation statistics
get_installation_stats() {
    local total=${TOTAL_TOOLS:-0}
    local success=${SUCCESSFUL_INSTALLS:-0}
    local failed=${FAILED_INSTALLS:-0}
    local skipped=${SKIPPED_INSTALLS:-0}
    
    if [[ $total -eq 0 ]]; then
        echo "Installation Statistics: No statistics available"
        return
    fi
    
    local success_rate=$((success * 100 / total))
    
    cat << EOF
Installation Statistics:
- Total tools defined: $total
- Successfully installed: $success
- Failed installations: $failed  
- Already installed (skipped): $skipped
- Success rate: ${success_rate}%
EOF
}

# Function to export tool installation results
export_tool_installation_vars() {
    export TOTAL_TOOLS
    export SUCCESSFUL_INSTALLS
    export FAILED_INSTALLS
    export SKIPPED_INSTALLS
    export INSTALLED_TOOLS
    export FAILED_TOOLS
    export SKIPPED_TOOLS
}